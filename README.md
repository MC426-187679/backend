# Back-End do Planejador de Disciplinas

Estrutura de backend usando Vapor, com testes unitários já integrados.

## Estrutura de folders:

```
.
├── Public (imagens, style sheets, browser scripts.. Precisa dar um enable no FileMiddleware dentro do configure.swift para funcionar)
├── Sources (código em swift)
│   ├── App (lógica da aplicação)
│   │   ├── Controllers (recebem um request e retornam uma response)
│   │   ├── Migrations (onde devem ser guardadas as database migrations se estivermos usando Fluent (?))
│   │   ├── Models (guardar Content structs ou Fluent Models)
│   │   ├── configure.swift (o metodo configure() é chamado pelo main, é onde devemos registrar serviços como routes, databases, providers, etc)
│   │   └── routes.swift (onde tem a função routes(), é chamado ao finall do configure() e registra routes para o app)
│   └── Run (target, contém apenas o código para ligar a aplicação)
│       └── main.swift (cria e roda uma instancia da nossa aplicação)
├── Tests (cada módulo não executável em Sources deve ter um correspondente aqui para fazer os testes unitários)
│   └── AppTests (testes para o moduele App)
└── Package.swift (swift package manager package manifest)
```
