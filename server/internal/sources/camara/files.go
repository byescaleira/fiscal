package camara

import (
	"archive/zip"
	"fmt"
	"io"
	"strings"

	"liveresults/internal/sources/table"
)

func open(r io.Reader, cols ...string) (*table.Reader, error) {
	t, err := table.NewReader(r, table.UTF8, ';')
	if err != nil {
		return nil, err
	}
	if err := t.Require(cols...); err != nil {
		return nil, err
	}
	return t, nil
}

func ReadAuthors(r io.Reader, fn func(Authorship)) error {
	t, err := open(r, "idProposicao", "idDeputadoAutor", "ordemAssinatura", "proponente")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		dep := atoi64(row.Raw("idDeputadoAutor"))
		if dep == 0 {
			return nil
		}
		fn(Authorship{
			PropositionID: atoi64(row.Raw("idProposicao")),
			DeputyID:      dep,
			Order:         atoi(row.Raw("ordemAssinatura")),
			Proponent:     row.Raw("proponente") == "1",
		})
		return nil
	})
}

func ReadPropositions(r io.Reader, keep func(int64) bool, fn func(Proposition)) error {
	t, err := open(r, "id", "siglaTipo", "numero", "ano", "ementa", "dataApresentacao")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		id := atoi64(row.Raw("id"))
		if id == 0 || (keep != nil && !keep(id)) {
			return nil
		}
		url := row.Raw("urlInteiroTeor")
		if url == "" {
			url = PropositionURL(id)
		}
		fn(Proposition{
			ID:         id,
			Kind:       row.Raw("siglaTipo"),
			Number:     atoi(row.Raw("numero")),
			Year:       atoi(row.Raw("ano")),
			Ementa:     CleanText(row.Raw("ementa")),
			Keywords:   row.Raw("keywords"),
			Presented:  row.Raw("dataApresentacao"),
			URL:        url,
			Situation:  row.Raw("ultimoStatus_descricaoSituacao"),
			StatusDate: row.Raw("ultimoStatus_dataHora"),
		})
		return nil
	})
}

func ReadVotes(r io.Reader, fn func(Vote)) error {
	t, err := open(r, "id", "data", "dataHoraRegistro", "idOrgao", "siglaOrgao", "idEvento", "aprovacao", "votosSim", "votosNao", "votosOutros", "descricao")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		v := Vote{
			ID:          row.Raw("id"),
			Date:        row.Raw("data"),
			Registered:  row.Raw("dataHoraRegistro"),
			OrganID:     atoi64(row.Raw("idOrgao")),
			Organ:       row.Raw("siglaOrgao"),
			EventID:     atoi64(row.Raw("idEvento")),
			Yes:         atoi(row.Raw("votosSim")),
			No:          atoi(row.Raw("votosNao")),
			Others:      atoi(row.Raw("votosOutros")),
			Description: CleanText(row.Raw("descricao")),
		}
		v.Approved = approval(row.Raw("aprovacao"))
		fn(v)
		return nil
	})
}

func approval(s string) *bool {
	switch strings.TrimSpace(s) {
	case "1":
		b := true
		return &b
	case "0":
		b := false
		return &b
	}
	return nil
}

func ReadBallots(r io.Reader, fn func(Ballot)) error {
	t, err := open(r, "idVotacao", "voto", "deputado_id", "deputado_nome", "deputado_siglaPartido", "deputado_siglaUf")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		fn(Ballot{
			VoteID:   row.Raw("idVotacao"),
			DeputyID: atoi64(row.Raw("deputado_id")),
			Name:     row.Raw("deputado_nome"),
			Party:    row.Raw("deputado_siglaPartido"),
			UF:       row.Raw("deputado_siglaUf"),
			Vote:     row.Raw("voto"),
		})
		return nil
	})
}

func ReadGuidance(r io.Reader, fn func(Guidance)) error {
	t, err := open(r, "idVotacao", "siglaBancada", "orientacao")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		g := row.Raw("orientacao")
		if g == "" {
			return nil
		}
		fn(Guidance{VoteID: row.Raw("idVotacao"), Bloc: row.Raw("siglaBancada"), Guidance: g})
		return nil
	})
}

func ReadVotePropositions(r io.Reader, fn func(VoteProposition)) error {
	t, err := open(r, "idVotacao", "proposicao_id", "proposicao_titulo", "proposicao_ementa", "proposicao_siglaTipo", "proposicao_numero", "proposicao_ano")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		fn(VoteProposition{
			VoteID:        row.Raw("idVotacao"),
			PropositionID: atoi64(row.Raw("proposicao_id")),
			Title:         row.Raw("proposicao_titulo"),
			Ementa:        CleanText(row.Raw("proposicao_ementa")),
			Kind:          row.Raw("proposicao_siglaTipo"),
			Number:        atoi(row.Raw("proposicao_numero")),
			Year:          atoi(row.Raw("proposicao_ano")),
		})
		return nil
	})
}

func ReadPresence(r io.Reader, fn func(Presence)) error {
	t, err := open(r, "idEvento", "idDeputado")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		fn(Presence{EventID: atoi64(row.Raw("idEvento")), DeputyID: atoi64(row.Raw("idDeputado"))})
		return nil
	})
}

func ReadEvents(r io.Reader, fn func(Event)) error {
	t, err := open(r, "id", "dataHoraInicio", "situacao", "descricaoTipo")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		fn(Event{
			ID:          atoi64(row.Raw("id")),
			Start:       row.Raw("dataHoraInicio"),
			End:         row.Raw("dataHoraFim"),
			Situation:   row.Raw("situacao"),
			Description: CleanText(row.Raw("descricao")),
			Type:        row.Raw("descricaoTipo"),
		})
		return nil
	})
}

func ReadEventOrgans(r io.Reader, fn func(eventID, organID int64)) error {
	t, err := open(r, "idEvento", "idOrgao")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		fn(atoi64(row.Raw("idEvento")), atoi64(row.Raw("idOrgao")))
		return nil
	})
}

func ReadCommittees(r io.Reader, fn func(Committee)) error {
	t, err := open(r, "siglaOrgao", "nomeOrgao", "uriDeputado", "cargo", "dataInicio", "dataFim")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		fn(Committee{
			DeputyID: idFromURI(row.Raw("uriDeputado")),
			Acronym:  row.Raw("siglaOrgao"),
			Name:     CleanText(row.Raw("nomeOrgao")),
			Role:     row.Raw("cargo"),
			Start:    row.Raw("dataInicio"),
			End:      row.Raw("dataFim"),
		})
		return nil
	})
}

func ReadExpenses(r io.Reader, fn func(Expense)) error {
	t, err := open(r, "ideCadastro", "cpf", "numMes", "numAno", "txtDescricao", "txtFornecedor", "txtCNPJCPF", "vlrLiquido")
	if err != nil {
		return err
	}
	return t.Each(func(row table.Row) error {
		dep := atoi64(row.Raw("ideCadastro"))
		if dep == 0 {
			return nil
		}
		cents, ok := row.Cents("vlrLiquido")
		if !ok {
			return nil
		}
		fn(Expense{
			DeputyID:   dep,
			CPF:        row.Raw("cpf"),
			Year:       atoi(row.Raw("numAno")),
			Month:      atoi(row.Raw("numMes")),
			Category:   row.Raw("txtDescricao"),
			Supplier:   row.Raw("txtFornecedor"),
			SupplierID: row.Raw("txtCNPJCPF"),
			Number:     row.Raw("txtNumero"),
			Cents:      cents,
			DocumentID: row.Raw("ideDocumento"),
			URL:        row.Raw("urlDocumento"),
		})
		return nil
	})
}

func ReadExpensesZip(path string, fn func(Expense)) error {
	zr, err := zip.OpenReader(path)
	if err != nil {
		return err
	}
	defer zr.Close()
	for _, f := range zr.File {
		if !strings.HasSuffix(strings.ToLower(f.Name), ".csv") {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return err
		}
		err = ReadExpenses(rc, fn)
		rc.Close()
		return err
	}
	return fmt.Errorf("camara: no CSV inside %s", path)
}
