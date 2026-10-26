package table

import (
	"bufio"
	"bytes"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"strconv"
	"strings"
	"unicode/utf8"
)

type Encoding int

const (
	UTF8 Encoding = iota
	Latin1
)

type Reader struct {
	csv    *csv.Reader
	index  map[string]int
	header []string
	line   int
}

type Row struct {
	r      *Reader
	fields []string
}

func NewReader(src io.Reader, enc Encoding, delim rune) (*Reader, error) {
	br := bufio.NewReaderSize(src, 1<<16)
	if enc == UTF8 {
		if head, err := br.Peek(3); err == nil && bytes.Equal(head, []byte{0xef, 0xbb, 0xbf}) {
			br.Discard(3)
		}
	}
	var in io.Reader = br
	if enc == Latin1 {
		in = &latin1Reader{src: br}
	}
	cr := csv.NewReader(in)
	cr.Comma = delim
	cr.LazyQuotes = true
	cr.FieldsPerRecord = -1
	cr.ReuseRecord = false
	header, err := cr.Read()
	if err != nil {
		if errors.Is(err, io.EOF) {
			return nil, errors.New("table: empty file")
		}
		return nil, fmt.Errorf("table: header: %w", err)
	}
	if len(header) > 0 {
		header[0] = strings.TrimPrefix(header[0], "\ufeff")
	}
	idx := make(map[string]int, len(header))
	for i, h := range header {
		idx[strings.TrimSpace(h)] = i
	}
	return &Reader{csv: cr, index: idx, header: header}, nil
}

func (r *Reader) Has(col string) bool {
	_, ok := r.index[col]
	return ok
}

func (r *Reader) Require(cols ...string) error {
	var missing []string
	for _, c := range cols {
		if !r.Has(c) {
			missing = append(missing, c)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("table: missing columns %s", strings.Join(missing, ", "))
	}
	return nil
}

func (r *Reader) Header() []string {
	return r.header
}

func (r *Reader) Next() (Row, error) {
	for {
		rec, err := r.csv.Read()
		if err != nil {
			return Row{}, err
		}
		r.line++
		if len(rec) == 1 && strings.TrimSpace(rec[0]) == "" {
			continue
		}
		return Row{r: r, fields: rec}, nil
	}
}

func (r *Reader) Each(fn func(Row) error) error {
	for {
		row, err := r.Next()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("table: line %d: %w", r.line+1, err)
		}
		if err := fn(row); err != nil {
			return err
		}
	}
}

func (row Row) Raw(col string) string {
	i, ok := row.r.index[col]
	if !ok || i >= len(row.fields) {
		return ""
	}
	return strings.TrimSpace(row.fields[i])
}

func (row Row) At(i int) string {
	if i < 0 || i >= len(row.fields) {
		return ""
	}
	return strings.TrimSpace(row.fields[i])
}

func (row Row) Str(col string) string {
	return Clean(row.Raw(col))
}

func (row Row) Int(col string) (int64, bool) {
	v := row.Str(col)
	if v == "" {
		return 0, false
	}
	n, err := strconv.ParseInt(v, 10, 64)
	if err != nil {
		return 0, false
	}
	return n, true
}

func (row Row) Cents(col string) (int64, bool) {
	v := row.Raw(col)
	if strings.HasPrefix(v, "#") {
		return 0, false
	}
	return ParseCents(v)
}

func Clean(v string) string {
	v = strings.TrimSpace(v)
	switch strings.ToUpper(v) {
	case "", "#NULO", "#NULO#", "#NE", "#NE#", "-1", "-3", "-4", "NÃO DIVULGÁVEL", "NAO DIVULGAVEL":
		return ""
	}
	return v
}

func ParseCents(s string) (int64, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0, false
	}
	neg := false
	if strings.HasPrefix(s, "-") {
		neg = true
		s = s[1:]
	}
	s = strings.TrimPrefix(s, "R$")
	s = strings.TrimSpace(s)
	var intPart, frac string
	if strings.Contains(s, ",") {
		s = strings.ReplaceAll(s, ".", "")
		parts := strings.SplitN(s, ",", 2)
		intPart, frac = parts[0], parts[1]
	} else if strings.Count(s, ".") == 1 {
		parts := strings.SplitN(s, ".", 2)
		intPart, frac = parts[0], parts[1]
	} else {
		intPart = strings.ReplaceAll(s, ".", "")
	}
	if intPart == "" {
		intPart = "0"
	}
	if !digits(intPart) || (frac != "" && !digits(frac)) {
		return 0, false
	}
	whole, err := strconv.ParseInt(intPart, 10, 64)
	if err != nil {
		return 0, false
	}
	cents := whole * 100
	padded := frac + "000"
	c, _ := strconv.ParseInt(padded[:2], 10, 64)
	cents += c
	if padded[2] >= '5' {
		cents++
	}
	if neg {
		cents = -cents
	}
	return cents, true
}

func digits(s string) bool {
	for i := 0; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return s != ""
}

type latin1Reader struct {
	src     io.Reader
	pending []byte
	buf     [32 << 10]byte
}

func (l *latin1Reader) Read(p []byte) (int, error) {
	if len(l.pending) > 0 {
		n := copy(p, l.pending)
		l.pending = l.pending[n:]
		return n, nil
	}
	max := len(p) / 2
	if max == 0 {
		max = 1
	}
	if max > len(l.buf) {
		max = len(l.buf)
	}
	n, err := l.src.Read(l.buf[:max])
	if n == 0 {
		return 0, err
	}
	var out bytes.Buffer
	out.Grow(n * 2)
	for _, b := range l.buf[:n] {
		if b < utf8.RuneSelf {
			out.WriteByte(b)
		} else {
			out.WriteRune(rune(b))
		}
	}
	data := out.Bytes()
	c := copy(p, data)
	if c < len(data) {
		l.pending = append(l.pending[:0], data[c:]...)
	}
	return c, err
}
