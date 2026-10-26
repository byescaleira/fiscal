package deploy_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const fakeDocker = `#!/bin/sh
set -eu
tags="$FAKE_DOCKER_TAGS"
ref() { printf '%s' "$1" | tr ':/' '__'; }
case "$1 $2" in
"image inspect")
  shift 2
  format=""
  if [ "$1" = "-f" ]; then format="$2"; shift 2; fi
  file="$tags/$(ref "$1")"
  [ -f "$file" ] || { echo "No such image: $1" >&2; exit 1; }
  read -r id label < "$file"
  case "$format" in
  *fiscal.sha*) printf '%s\n' "${label:-}" ;;
  *.Id*) printf '%s\n' "$id" ;;
  esac
  ;;
"tag "*)
  src="$tags/$(ref "$2")"
  [ -f "$src" ] || { echo "No such image: $2" >&2; exit 1; }
  cp "$src" "$tags/$(ref "$3")"
  ;;
*) echo "unexpected: $*" >&2; exit 1 ;;
esac
`

type images struct {
	t    *testing.T
	dir  string
	tags string
}

func newImages(t *testing.T) *images {
	t.Helper()
	dir := t.TempDir()
	bin := filepath.Join(dir, "bin")
	tags := filepath.Join(dir, "tags")
	for _, d := range []string{bin, tags} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(bin, "docker"), []byte(fakeDocker), 0o755); err != nil {
		t.Fatal(err)
	}
	return &images{t: t, dir: dir, tags: tags}
}

func (im *images) build(tag, id, label string) {
	im.t.Helper()
	name := strings.NewReplacer(":", "_", "/", "_").Replace(tag)
	if err := os.WriteFile(filepath.Join(im.tags, name), []byte(id+" "+label+"\n"), 0o644); err != nil {
		im.t.Fatal(err)
	}
}

func (im *images) id(tag string) string {
	im.t.Helper()
	data, err := os.ReadFile(filepath.Join(im.tags, strings.NewReplacer(":", "_", "/", "_").Replace(tag)))
	if err != nil {
		return ""
	}
	return strings.Fields(string(data))[0]
}

func (im *images) promote(name, sha string) string {
	im.t.Helper()
	cmd := exec.Command("sh", "promote-image.sh", name, sha)
	cmd.Env = append(os.Environ(), "PATH="+filepath.Join(im.dir, "bin")+":/usr/bin:/bin", "FAKE_DOCKER_TAGS="+im.tags)
	out, err := cmd.CombinedOutput()
	if err != nil {
		im.t.Fatalf("promote %s %s: %v\n%s", name, sha, err, out)
	}
	return string(out)
}

func TestPromoteKeepsPreviousWhenTheShaIsAlreadyCurrent(t *testing.T) {
	im := newImages(t)
	im.build("fiscal-api:aaaaaaaaaaaa", "sha256:old", "aaaaaaaaaaaa")
	im.promote("api", "aaaaaaaaaaaa")
	if im.id("fiscal-api:current") != "sha256:old" || im.id("fiscal-api:previous") != "" {
		t.Fatalf("first promote: current=%s previous=%s", im.id("fiscal-api:current"), im.id("fiscal-api:previous"))
	}
	im.build("fiscal-api:bbbbbbbbbbbb", "sha256:new", "bbbbbbbbbbbb")
	im.promote("api", "bbbbbbbbbbbb")
	if im.id("fiscal-api:current") != "sha256:new" || im.id("fiscal-api:previous") != "sha256:old" {
		t.Fatalf("new sha: current=%s previous=%s", im.id("fiscal-api:current"), im.id("fiscal-api:previous"))
	}
	out := im.promote("api", "bbbbbbbbbbbb")
	if im.id("fiscal-api:previous") != "sha256:old" || !strings.Contains(out, "já é a current") {
		t.Fatalf("same sha again moved previous to %s (%s)", im.id("fiscal-api:previous"), out)
	}
	im.build("fiscal-api:bbbbbbbbbbbb", "sha256:rebuilt", "bbbbbbbbbbbb")
	im.promote("api", "bbbbbbbbbbbb")
	if im.id("fiscal-api:current") != "sha256:rebuilt" || im.id("fiscal-api:previous") != "sha256:old" {
		t.Fatalf("rebuilt same sha: current=%s previous=%s", im.id("fiscal-api:current"), im.id("fiscal-api:previous"))
	}
}

func TestPromoteFallsBackToLatestAndRejectsBadInput(t *testing.T) {
	im := newImages(t)
	im.build("fiscal-pages:latest", "sha256:legacy", "")
	im.build("fiscal-pages:cccccccccccc", "sha256:next", "cccccccccccc")
	im.promote("pages", "cccccccccccc")
	if im.id("fiscal-pages:previous") != "sha256:legacy" || im.id("fiscal-pages:current") != "sha256:next" {
		t.Fatalf("latest fallback: current=%s previous=%s", im.id("fiscal-pages:current"), im.id("fiscal-pages:previous"))
	}
	for _, args := range [][]string{{"web", "cccccccccccc"}, {"api", "main;rm"}, {"api", ""}} {
		cmd := exec.Command("sh", append([]string{"promote-image.sh"}, args...)...)
		cmd.Env = append(os.Environ(), "PATH="+filepath.Join(im.dir, "bin")+":/usr/bin:/bin", "FAKE_DOCKER_TAGS="+im.tags)
		if err := cmd.Run(); err == nil {
			t.Errorf("%v must fail", args)
		}
	}
}
