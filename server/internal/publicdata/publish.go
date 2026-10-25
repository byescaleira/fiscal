package publicdata

import (
	"fmt"

	"liveresults/internal/publish"
)

var ManagedDirs = []string{"people", "votes", "places", "index", "agenda", "money", "method"}

func Publish(out Output, tree *publish.Tree, prune bool) error {
	for _, f := range out.Files {
		if err := tree.WriteJSON(f.Path, f.Value); err != nil {
			return fmt.Errorf("publish %s: %w", f.Path, err)
		}
	}
	if prune {
		return tree.Prune(ManagedDirs...)
	}
	return nil
}
