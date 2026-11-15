import Foundation

nonisolated enum GitLabUserEndpoints {
    static func search(
        query: String
    ) -> GitLabAPIRequest<[GitLabAPIUser]> {
        .get(
            requires: .read,
            path: ["users"],
            query: [
                URLQueryItem(
                    name: "search",
                    value: query
                ),
                URLQueryItem(
                    name: "per_page",
                    value: "20"
                ),
            ]
        )
    }

    static func profile(
        userID: Int
    ) -> GitLabAPIRequest<GitLabUserProfile> {
        .get(
            requires: .read,
            path: ["users", String(userID)]
        )
    }

    static func status(
        userID: Int
    ) -> GitLabAPIRequest<GitLabUserStatus> {
        .get(
            requires: .read,
            path: [
                "users",
                String(userID),
                "status",
            ]
        )
    }

    static func gpgKeys(
        userID: Int
    ) -> GitLabAPIRequest<[GitLabUserGPGKey]> {
        .get(
            requires: .read,
            path: [
                "users",
                String(userID),
                "gpg_keys",
            ]
        )
    }

    static func follow(
        userID: Int
    ) -> GitLabAPIRequest<GitLabEmptyResponse> {
        .post(
            requires: .write,
            path: [
                "users",
                String(userID),
                "follow",
            ]
        )
    }

    static func unfollow(
        userID: Int
    ) -> GitLabAPIRequest<GitLabEmptyResponse> {
        .post(
            requires: .write,
            path: [
                "users",
                String(userID),
                "unfollow",
            ]
        )
    }
}
