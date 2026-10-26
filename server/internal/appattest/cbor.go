package appattest

import (
	"encoding/binary"
	"errors"
	"fmt"
)

const (
	maxDepth = 8
	maxItems = 64
)

var errCBOR = errors.New("appattest: malformed CBOR")

type decoder struct {
	data []byte
	pos  int
}

func decodeCBOR(data []byte) (any, error) {
	d := &decoder{data: data}
	v, err := d.value(0)
	if err != nil {
		return nil, err
	}
	if d.pos != len(d.data) {
		return nil, fmt.Errorf("%w: trailing bytes", errCBOR)
	}
	return v, nil
}

func (d *decoder) need(n uint64) error {
	if n > uint64(len(d.data)-d.pos) {
		return fmt.Errorf("%w: truncated", errCBOR)
	}
	return nil
}

func (d *decoder) head() (byte, uint64, error) {
	if err := d.need(1); err != nil {
		return 0, 0, err
	}
	b := d.data[d.pos]
	d.pos++
	major, info := b>>5, b&0x1f
	switch {
	case info < 24:
		return major, uint64(info), nil
	case info == 24:
		if err := d.need(1); err != nil {
			return 0, 0, err
		}
		v := uint64(d.data[d.pos])
		d.pos++
		return major, v, nil
	case info == 25:
		if err := d.need(2); err != nil {
			return 0, 0, err
		}
		v := uint64(binary.BigEndian.Uint16(d.data[d.pos:]))
		d.pos += 2
		return major, v, nil
	case info == 26:
		if err := d.need(4); err != nil {
			return 0, 0, err
		}
		v := uint64(binary.BigEndian.Uint32(d.data[d.pos:]))
		d.pos += 4
		return major, v, nil
	case info == 27:
		if err := d.need(8); err != nil {
			return 0, 0, err
		}
		v := binary.BigEndian.Uint64(d.data[d.pos:])
		d.pos += 8
		return major, v, nil
	}
	return 0, 0, fmt.Errorf("%w: indefinite or reserved length", errCBOR)
}

func (d *decoder) value(depth int) (any, error) {
	if depth > maxDepth {
		return nil, fmt.Errorf("%w: too deep", errCBOR)
	}
	major, n, err := d.head()
	if err != nil {
		return nil, err
	}
	switch major {
	case 0:
		return n, nil
	case 1:
		return -1 - int64(n&0x7fffffffffffffff), nil
	case 2, 3:
		if err := d.need(n); err != nil {
			return nil, err
		}
		b := append([]byte(nil), d.data[d.pos:d.pos+int(n)]...)
		d.pos += int(n)
		if major == 3 {
			return string(b), nil
		}
		return b, nil
	case 4:
		if n > maxItems {
			return nil, fmt.Errorf("%w: array too long", errCBOR)
		}
		out := make([]any, 0, n)
		for range n {
			v, err := d.value(depth + 1)
			if err != nil {
				return nil, err
			}
			out = append(out, v)
		}
		return out, nil
	case 5:
		if n > maxItems {
			return nil, fmt.Errorf("%w: map too long", errCBOR)
		}
		out := make(map[string]any, n)
		for range n {
			k, err := d.value(depth + 1)
			if err != nil {
				return nil, err
			}
			ks, ok := k.(string)
			if !ok {
				return nil, fmt.Errorf("%w: non-text map key", errCBOR)
			}
			v, err := d.value(depth + 1)
			if err != nil {
				return nil, err
			}
			if _, dup := out[ks]; dup {
				return nil, fmt.Errorf("%w: duplicate key", errCBOR)
			}
			out[ks] = v
		}
		return out, nil
	case 6:
		return d.value(depth + 1)
	case 7:
		switch n {
		case 20:
			return false, nil
		case 21:
			return true, nil
		case 22, 23:
			return nil, nil
		}
	}
	return nil, fmt.Errorf("%w: unsupported type", errCBOR)
}
