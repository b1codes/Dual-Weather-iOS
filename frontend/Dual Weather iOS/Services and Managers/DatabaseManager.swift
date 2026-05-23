//
//  DatabaseManager.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 2/2/25.
//

import Firebase
import FirebaseFirestore

class DatabaseManager {
    static let shared = DatabaseManager()
    private let database = Firestore.firestore()

    private init() {}

    // Fetch all locations
    func fetchLocations(completion: @escaping (Result<[Location], Error>) -> Void) {
        database.collection("locations").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let locations = documents.compactMap { document -> Location? in
                return Location(document: document.data())
            }
            completion(.success(locations))
        }
    }

    // Fetch a specific location by document ID
    func fetchLocation(by id: String, completion: @escaping (Result<Location, Error>) -> Void) {
        database.collection("locations").document(id).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let document = document, document.exists,
                  let data = document.data(),
                  let location = Location(document: data) else {
                completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document not found."])))
                return
            }

            completion(.success(location))
        }
    }
}
