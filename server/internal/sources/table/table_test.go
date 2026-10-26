package table

import (
	"bytes"
	"strings"
	"testing"
)

func TestParseCents(t *testing.T) {
	cases := []struct {
		in   string
		want int64
		ok   bool
	}{
		{"20000,00", 2000000, true},
		{"1.470.000,00", 147000000, true},
		{"954.3", 95430, true},
		{"1467", 146700, true},
		{"-0,78", -78, true},
		{"102706584,5", 10270658450, true},
		{"6141454,232", 614145423, true},
		{"0,505", 51, true},
		{"4576.32", 457632, true},
		{"", 0, false},
		{"#NULO", 0, false},
		{"abc", 0, false},
		{"1,2,3", 0, false},
	}
	for _, c := range cases {
		got, ok := ParseCents(c.in)
		if got != c.want || ok != c.ok {
			t.Errorf("ParseCents(%q) = %d, %v; want %d, %v", c.in, got, ok, c.want, c.ok)
		}
	}
}

func TestReaderHandlesBOMQuotesAndMultilineFields(t *testing.T) {
	src := "\ufeff\"id\";\"descricao\";\"valor\"\n\"1\";\"linha um\nlinha dois\";\"10,5\"\n\n\"2\";\"#NULO\";\"-1\"\n"
	r, err := NewReader(strings.NewReader(src), UTF8, ';')
	if err != nil {
		t.Fatal(err)
	}
	if err := r.Require("id", "descricao", "valor"); err != nil {
		t.Fatal(err)
	}
	if err := r.Require("nope"); err == nil {
		t.Fatal("missing column not reported")
	}
	var rows []Row
	r.Each(func(row Row) error {
		rows = append(rows, row)
		return nil
	})
	if len(rows) != 2 {
		t.Fatalf("rows = %d", len(rows))
	}
	if rows[0].Str("descricao") != "linha um\nlinha dois" {
		t.Fatalf("multiline = %q", rows[0].Str("descricao"))
	}
	if c, ok := rows[0].Cents("valor"); !ok || c != 1050 {
		t.Fatalf("cents = %d %v", c, ok)
	}
	if rows[1].Str("descricao") != "" || rows[1].Str("valor") != "" {
		t.Fatal("TSE null markers must read as empty")
	}
	if c, ok := rows[1].Cents("valor"); !ok || c != -100 {
		t.Fatalf("a literal -1 amount is a real value, got %d %v", c, ok)
	}
	if n, ok := rows[0].Int("id"); !ok || n != 1 {
		t.Fatal("int")
	}
}

func TestLatin1Decoding(t *testing.T) {
	src := []byte("\"NM\";\"UF\"\n\"JO\xc3O\";\"S\xc3O PAULO\"\n")
	r, err := NewReader(bytes.NewReader(src), Latin1, ';')
	if err != nil {
		t.Fatal(err)
	}
	row, err := r.Next()
	if err != nil {
		t.Fatal(err)
	}
	if row.Str("NM") != "JOÃO" || row.Str("UF") != "SÃO PAULO" {
		t.Fatalf("decoded = %q %q", row.Str("NM"), row.Str("UF"))
	}
}

func TestLatin1ReaderWithTinyBuffers(t *testing.T) {
	l := &latin1Reader{src: bytes.NewReader([]byte("\xe1\xe9\xed\xf3\xfa"))}
	var out []byte
	buf := make([]byte, 1)
	for {
		n, err := l.Read(buf)
		out = append(out, buf[:n]...)
		if err != nil {
			break
		}
	}
	if string(out) != "áéíóú" {
		t.Fatalf("got %q", out)
	}
}
