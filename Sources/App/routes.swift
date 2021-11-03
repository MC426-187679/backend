import Vapor


func routes(_ app: Application) throws {
    let api = app.grouped("api")
    
    
    // API: busca textual entre vários elementos.
    api.get("busca") { req -> Future<[Match]> in
        return try SearchController.shared.searchFor(req)
    }
    
    // API: dados para a página de uma disciplina
    api.get("disciplina", ":code") { req -> Discipline in
        return try Discipline.Controller.shared.fetchDiscipline(req)
    }
    
    // API: dados para a página de um curso
    api.get("curso", ":code") { req -> Course in
        return try Course.Controller.shared.fetchCourse(req)
    }
    
    // API: dados para a página de árvore do curso
    api.get("curso", ":code", ":variant") { req -> CourseTree in
        return try Course.Controller.shared.fetchCourseTree(req)
    }
}
