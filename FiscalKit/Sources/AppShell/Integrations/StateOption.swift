import AppIntents

public enum StateOption: String, AppEnum {
    case ac, al, am, ap, ba, ce, df, es, go, ma, mg, ms, mt, pa
    case pb, pe, pi, pr, rj, rn, ro, rr, rs, sc, se, sp, to

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "State")
    }

    public static var caseDisplayRepresentations: [StateOption: DisplayRepresentation] {
        [
            .ac: "Acre", .al: "Alagoas", .am: "Amazonas", .ap: "Amapá", .ba: "Bahia",
            .ce: "Ceará", .df: "Distrito Federal", .es: "Espírito Santo", .go: "Goiás",
            .ma: "Maranhão", .mg: "Minas Gerais", .ms: "Mato Grosso do Sul", .mt: "Mato Grosso",
            .pa: "Pará", .pb: "Paraíba", .pe: "Pernambuco", .pi: "Piauí", .pr: "Paraná",
            .rj: "Rio de Janeiro", .rn: "Rio Grande do Norte", .ro: "Rondônia", .rr: "Roraima",
            .rs: "Rio Grande do Sul", .sc: "Santa Catarina", .se: "Sergipe", .sp: "São Paulo",
            .to: "Tocantins",
        ]
    }
}
