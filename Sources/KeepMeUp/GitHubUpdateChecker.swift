import Foundation
import KeepMeUpCore

/// Describes the subset of a GitHub release used by the update interface.
struct GitHubRelease: Decodable, Equatable {
  /// The release tag, conventionally formatted as `vMAJOR.MINOR.PATCH`.
  let tagName: String

  /// The public release page opened for manual installation.
  let pageURL: URL

  /// Maps GitHub's snake-case response fields into Swift property names.
  private enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
    case pageURL = "html_url"
  }
}

/// Represents every expected outcome of an unauthenticated GitHub release lookup.
enum UpdateCheckOutcome: Equatable {
  case updateAvailable(GitHubRelease)
  case upToDate
  case noPublishedRelease
}

/// Describes update-check failures that can be presented without leaking response data.
enum UpdateCheckError: LocalizedError {
  case invalidResponse
  case serverStatus(Int)
  case invalidRelease

  /// Returns a concise user-facing message for a failed update check.
  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "GitHub returned an unreadable response."
    case .serverStatus(let statusCode):
      return "GitHub returned HTTP status \(statusCode)."
    case .invalidRelease:
      return "The latest GitHub release has an invalid version tag."
    }
  }
}

/// Checks the public GitHub Releases API without credentials, analytics, or background downloads.
final class GitHubUpdateChecker {
  /// The URL session used to perform the public metadata request.
  private let session: URLSession

  /// Creates an update checker with an injectable session for future integration testing.
  init(session: URLSession = .shared) {
    self.session = session
  }

  /// Compares the latest published GitHub release against the app's bundled version.
  func check(completion: @escaping (Result<UpdateCheckOutcome, Error>) -> Void) {
    var request = URLRequest(url: AppConstants.latestReleaseAPIURL)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("KeepMeUp/\(AppConstants.currentVersion)", forHTTPHeaderField: "User-Agent")

    session.dataTask(with: request) { data, response, error in
      if let error {
        self.completeOnMain(.failure(error), completion: completion)
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        self.completeOnMain(.failure(UpdateCheckError.invalidResponse), completion: completion)
        return
      }

      if httpResponse.statusCode == 404 {
        self.completeOnMain(.success(.noPublishedRelease), completion: completion)
        return
      }

      guard httpResponse.statusCode == 200 else {
        self.completeOnMain(
          .failure(UpdateCheckError.serverStatus(httpResponse.statusCode)),
          completion: completion
        )
        return
      }

      guard let data,
        let release = try? JSONDecoder().decode(GitHubRelease.self, from: data),
        let releaseVersion = SemanticVersion(release.tagName),
        let currentVersion = SemanticVersion(AppConstants.currentVersion)
      else {
        self.completeOnMain(.failure(UpdateCheckError.invalidRelease), completion: completion)
        return
      }

      let outcome: UpdateCheckOutcome =
        currentVersion < releaseVersion
        ? .updateAvailable(release)
        : .upToDate
      self.completeOnMain(.success(outcome), completion: completion)
    }.resume()
  }

  /// Delivers all outcomes on the main queue because callers update AppKit controls.
  private func completeOnMain(
    _ result: Result<UpdateCheckOutcome, Error>,
    completion: @escaping (Result<UpdateCheckOutcome, Error>) -> Void
  ) {
    DispatchQueue.main.async {
      completion(result)
    }
  }
}
