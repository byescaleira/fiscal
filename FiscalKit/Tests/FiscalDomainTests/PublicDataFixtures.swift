enum PublicDataFixtures {
    static let stateDeputyProfile = #"""
        {
          "slug": "ana-souza-ba", "name": "Ana Souza", "civilName": "Ana Maria de Souza",
          "office": "stateDeputy", "uf": "ba", "party": "PSD", "photo": null,
          "status": "electedAwaiting",
          "mandate": { "start": "2027-02-01", "end": "2031-01-31" },
          "birthDate": "1978-05-14", "birthPlace": "Salvador", "education": null,
          "contact": null, "salary": null,
          "numbers": {
            "attendance": null, "proposals": null, "laws": null, "speeches": null, "votes": null,
            "quotaCents": null, "assetsCents": 125000000, "campaignRevenueCents": 98000000,
            "lastElectionVotes": 41230
          },
          "years": [],
          "themes": [
            { "key": "educacao", "proposals": 3, "speeches": 1 },
            { "key": "saude", "proposals": 1, "speeches": 0 }
          ],
          "committees": [],
          "assets": [{ "year": 2026, "totalCents": 125000000, "items": [{ "kind": "Imóvel", "cents": 125000000 }] }],
          "campaigns": [{ "year": 2026, "office": "Deputado estadual", "result": "Eleito", "revenueCents": 98000000, "expenseCents": 91000000 }],
          "timeline": [{ "year": 2026, "office": "Deputado estadual", "place": "Bahia", "party": "PSD", "result": "Eleito", "votes": 41230 }],
          "coverage": [
            { "kind": "votes", "status": "notPublished", "source": null },
            { "kind": "assets", "status": "available", "source": "tse" }
          ],
          "sources": [{ "id": "tse", "name": "TSE", "url": "https://dadosabertos.tse.jus.br", "updatedAt": "2026-10-25T05:42:00-03:00" }]
        }
        """#

    static let expenses = #"""
        {
          "items": [{ "id": "e1", "year": 2026, "month": 3, "category": "Passagens aéreas", "supplier": "GOL Linhas Aéreas", "document": null, "cents": 1250075, "url": null }],
          "totalCents": 1250075,
          "byMonth": [{ "month": 3, "cents": 1250075 }],
          "byCategory": [{ "category": "Passagens aéreas", "cents": 1250075, "count": 1 }]
        }
        """#

    static let voteDetail = #"""
        {
          "id": "camara-2416587", "house": "camara", "date": "2026-10-21", "time": "18:42",
          "proposition": "PL 1873/2026", "kind": "Projeto de Lei",
          "summary": "Altera a Lei nº 9.250, de 1995.", "plainSummary": "Muda uma lei do imposto de renda.",
          "themes": ["impostos"], "result": "Aprovado", "approved": true, "nominal": true,
          "yes": 412, "no": 49, "others": 9,
          "quorum": 257,
          "guidance": [{ "party": "PL", "guidance": "Sim" }],
          "parties": [{ "party": "PL", "yes": 80, "no": 6, "others": 2 }],
          "people": [{ "slug": "nikolas-ferreira", "name": "Nikolas Ferreira", "party": "PL", "uf": "mg", "vote": "Sim" }],
          "sources": []
        }
        """#

    static let money = #"""
        {
          "year": 2026,
          "quota": { "federalDeputiesCents": 19840000000, "senatorsCents": 2715000000, "byCategory": [] },
          "salaries": [{ "office": "federalDeputy", "monthlyCents": 4636619, "law": "Decreto Legislativo 172/2022" }],
          "campaigns": { "year": 2022, "revenueCents": 612000000000, "expenseCents": 598000000000, "byOrigin": [{ "origin": "Fundo Partidário", "cents": 61000000000 }] },
          "revenue": null,
          "sources": []
        }
        """#
}
