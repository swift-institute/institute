public import Institute_Model

public import GitHub
public import GitHub_HTTP

extension Institute.Inventory {
    public static func client<Execution, Pagination>(
        _ http: GitHub.HTTP.Client<Execution, Pagination>,
        authentication: GitHub.HTTP.Authentication
    ) -> Client<GitHub.HTTP.Error<Execution, Never>>
    where
        Execution: Swift.Error,
        Pagination: Swift.Error
    {
        .init(
            repositories: http.repositories(authentication: authentication),
            content: http.content(authentication: authentication)
        )
    }
}
