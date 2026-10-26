package xlsx

import (
	"archive/zip"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"strconv"
	"strings"
)

const maxPart = 256 << 20

type Row map[int]string

func FirstSheet(r io.ReaderAt, size int64) ([]Row, error) {
	z, err := zip.NewReader(r, size)
	if err != nil {
		return nil, fmt.Errorf("xlsx: %w", err)
	}
	files := map[string]*zip.File{}
	for _, f := range z.File {
		files[f.Name] = f
	}
	var shared []string
	if f, ok := files["xl/sharedStrings.xml"]; ok {
		if shared, err = readShared(f); err != nil {
			return nil, err
		}
	}
	sheet, ok := files["xl/worksheets/sheet1.xml"]
	if !ok {
		return nil, errors.New("xlsx: no first sheet")
	}
	return readSheet(sheet, shared)
}

func open(f *zip.File) (io.ReadCloser, error) {
	if f.UncompressedSize64 > maxPart {
		return nil, fmt.Errorf("xlsx: %s larger than %d bytes", f.Name, maxPart)
	}
	rc, err := f.Open()
	if err != nil {
		return nil, fmt.Errorf("xlsx: %w", err)
	}
	return rc, nil
}

func readShared(f *zip.File) ([]string, error) {
	rc, err := open(f)
	if err != nil {
		return nil, err
	}
	defer rc.Close()
	dec := xml.NewDecoder(io.LimitReader(rc, maxPart))
	var out []string
	var cur strings.Builder
	inSI, inT := false, false
	for {
		tok, err := dec.Token()
		if err == io.EOF {
			return out, nil
		}
		if err != nil {
			return nil, fmt.Errorf("xlsx: shared strings: %w", err)
		}
		switch t := tok.(type) {
		case xml.StartElement:
			switch t.Name.Local {
			case "si":
				inSI = true
				cur.Reset()
			case "t":
				inT = inSI
			case "rPh":
				inT = false
			}
		case xml.EndElement:
			switch t.Name.Local {
			case "si":
				out = append(out, cur.String())
				inSI = false
			case "t":
				inT = false
			}
		case xml.CharData:
			if inT {
				cur.Write(t)
			}
		}
	}
}

func readSheet(f *zip.File, shared []string) ([]Row, error) {
	rc, err := open(f)
	if err != nil {
		return nil, err
	}
	defer rc.Close()
	dec := xml.NewDecoder(io.LimitReader(rc, maxPart))
	var rows []Row
	var row Row
	col, kind := -1, ""
	var val strings.Builder
	inV, inIS := false, false
	for {
		tok, err := dec.Token()
		if err == io.EOF {
			return rows, nil
		}
		if err != nil {
			return nil, fmt.Errorf("xlsx: sheet: %w", err)
		}
		switch t := tok.(type) {
		case xml.StartElement:
			switch t.Name.Local {
			case "row":
				row = Row{}
			case "c":
				col, kind = -1, ""
				val.Reset()
				for _, a := range t.Attr {
					switch a.Name.Local {
					case "r":
						col = column(a.Value)
					case "t":
						kind = a.Value
					}
				}
			case "v":
				inV = true
			case "is":
				inIS = true
			case "t":
				inV = inIS
			}
		case xml.EndElement:
			switch t.Name.Local {
			case "row":
				rows = append(rows, row)
				row = nil
			case "c":
				if row != nil && col >= 0 && val.Len() > 0 {
					row[col] = cell(val.String(), kind, shared)
				}
			case "v":
				inV = false
			case "is":
				inIS = false
			case "t":
				inV = false
			}
		case xml.CharData:
			if inV {
				val.Write(t)
			}
		}
	}
}

func cell(v, kind string, shared []string) string {
	if kind == "s" {
		i, err := strconv.Atoi(strings.TrimSpace(v))
		if err != nil || i < 0 || i >= len(shared) {
			return ""
		}
		return shared[i]
	}
	return v
}

func column(ref string) int {
	n := 0
	seen := false
	for _, r := range ref {
		if r < 'A' || r > 'Z' {
			break
		}
		n = n*26 + int(r-'A'+1)
		seen = true
	}
	if !seen {
		return -1
	}
	return n - 1
}
