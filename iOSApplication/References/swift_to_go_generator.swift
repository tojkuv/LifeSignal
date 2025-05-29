import Foundation

// MARK: - Annotations for Backend Contract Generation

@attached(peer)
macro BackendService() = #externalMacro(module: "BackendMacros", type: "BackendServiceMacro")

@attached(peer) 
macro BackendContract(service: String, basePath: String) = #externalMacro(module: "BackendMacros", type: "BackendContractMacro")

@attached(peer)
macro HTTPMethod(_ method: HTTPMethodType, path: String) = #externalMacro(module: "BackendMacros", type: "HTTPMethodMacro")

@attached(peer)
macro GET(_ path: String) = #externalMacro(module: "BackendMacros", type: "GETMacro")

@attached(peer)
macro POST(_ path: String) = #externalMacro(module: "BackendMacros", type: "POSTMacro")

@attached(peer)
macro PUT(_ path: String) = #externalMacro(module: "BackendMacros", type: "PUTMacro")

@attached(peer)
macro DELETE(_ path: String) = #externalMacro(module: "BackendMacros", type: "DELETEMacro")

@attached(peer)
macro APIContract() = #externalMacro(module: "BackendMacros", type: "APIContractMacro")

enum HTTPMethodType: String, CaseIterable {
    case GET = "GET"
    case POST = "POST" 
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Example Protocol Definitions (Source of Truth)

@BackendContract(
    service: "UserService",
    basePath: "/api/v1/users"
)
protocol UserService {
    @GET("/{id}")
    func getUser(id: String) async throws -> User
    
    @POST("/")
    func createUser(_ user: CreateUserRequest) async throws -> User
    
    @PUT("/{id}")
    func updateUser(id: String, _ user: UpdateUserRequest) async throws -> User
    
    @DELETE("/{id}")
    func deleteUser(id: String) async throws -> Void
    
    @GET("/")
    func listUsers(limit: Int?, offset: Int?) async throws -> UserListResponse
}

@BackendContract(
    service: "AuthService", 
    basePath: "/api/v1/auth"
)
protocol AuthService {
    @POST("/login")
    func login(_ credentials: LoginRequest) async throws -> AuthResponse
    
    @POST("/refresh")
    func refreshToken(_ request: RefreshTokenRequest) async throws -> AuthResponse
    
    @POST("/logout")
    func logout() async throws -> Void
}

@APIContract
protocol OrderService {
    func getOrder(id: String) async throws -> Order
    func createOrder(_ order: CreateOrderRequest) async throws -> Order
    func updateOrderStatus(id: String, status: OrderStatus) async throws -> Order
    func cancelOrder(id: String) async throws -> Void
}

// MARK: - Data Models

struct User: Codable {
    let id: String
    let name: String
    let email: String
    let createdAt: Date
    let updatedAt: Date
}

struct CreateUserRequest: Codable {
    let name: String
    let email: String
    let password: String
}

struct UpdateUserRequest: Codable {
    let name: String?
    let email: String?
}

struct UserListResponse: Codable {
    let users: [User]
    let total: Int
    let hasMore: Bool
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User
}

struct Order: Codable {
    let id: String
    let userId: String
    let items: [OrderItem]
    let status: OrderStatus
    let total: Double
    let createdAt: Date
}

struct OrderItem: Codable {
    let productId: String
    let quantity: Int
    let price: Double
}

struct CreateOrderRequest: Codable {
    let userId: String
    let items: [OrderItem]
}

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case shipped = "shipped"
    case delivered = "delivered"
    case cancelled = "cancelled"
}

// MARK: - Protocol Information Extraction

struct ProtocolInfo {
    let name: String
    let methods: [MethodInfo]
    let annotations: [String: String]
}

struct MethodInfo {
    let name: String
    let parameters: [ParameterInfo]
    let returnType: String
    let httpMethod: String?
    let path: String?
    let isAsync: Bool
    let canThrow: Bool
}

struct ParameterInfo {
    let name: String
    let type: String
    let isOptional: Bool
}

// MARK: - Code Generation Engine

class BackendGenerator {
    
    static func generateGoCode(from protocols: [ProtocolInfo]) -> String {
        var output = """
        // Code generated from Swift protocols - DO NOT EDIT
        package main
        
        import (
            "context"
            "encoding/json"
            "net/http"
            "time"
            
            "github.com/gin-gonic/gin"
        )
        
        """
        
        for protocolInfo in protocols {
            output += generateGoInterface(from: protocolInfo)
            output += "\n"
            output += generateGoHTTPHandlers(from: protocolInfo)
            output += "\n"
        }
        
        return output
    }
    
    private static func generateGoInterface(from protocol: ProtocolInfo) -> String {
        var output = """
        // \(protocol.name) interface generated from Swift protocol
        type \(protocol.name) interface {
        
        """
        
        for method in protocol.methods {
            let goMethod = convertToGoMethod(method)
            output += "    \(goMethod)\n"
        }
        
        output += "}\n"
        return output
    }
    
    private static func generateGoHTTPHandlers(from protocol: ProtocolInfo) -> String {
        guard let basePath = protocol.annotations["basePath"] else {
            return ""
        }
        
        var output = """
        // HTTP handlers for \(protocol.name)
        func Setup\(protocol.name)Routes(r *gin.Engine, service \(protocol.name)) {
        
        """
        
        for method in protocol.methods {
            if let httpMethod = method.httpMethod, let path = method.path {
                let fullPath = basePath + path
                let handlerName = "handle\(method.name.capitalized)"
                
                output += """
                    r.\(httpMethod.uppercased())("\(fullPath)", \(handlerName)(service))
                
                """
            }
        }
        
        output += "}\n\n"
        
        // Generate individual handler functions
        for method in protocol.methods {
            if method.httpMethod != nil {
                output += generateGoHandler(for: method)
                output += "\n"
            }
        }
        
        return output
    }
    
    private static func generateGoHandler(for method: MethodInfo) -> String {
        let handlerName = "handle\(method.name.capitalized)"
        
        var output = """
        func \(handlerName)(service \(method.name.contains("User") ? "UserService" : "AuthService")) gin.HandlerFunc {
            return func(c *gin.Context) {
        
        """
        
        // Parameter extraction
        for param in method.parameters {
            if param.name == "id" {
                output += """
                        \(param.name) := c.Param("\(param.name)")
                
                """
            } else if method.httpMethod == "POST" || method.httpMethod == "PUT" {
                output += """
                        var \(param.name) \(swiftTypeToGo(param.type))
                        if err := c.ShouldBindJSON(&\(param.name)); err != nil {
                            c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
                            return
                        }
                
                """
            }
        }
        
        // Service call
        let serviceCall = generateServiceCall(for: method)
        output += serviceCall
        
        output += """
            }
        }
        
        """
        
        return output
    }
    
    private static func generateServiceCall(for method: MethodInfo) -> String {
        let params = method.parameters.map { $0.name }.joined(separator: ", ")
        let paramList = params.isEmpty ? "c.Request.Context()" : "c.Request.Context(), \(params)"
        
        if method.returnType == "Void" {
            return """
                    if err := service.\(method.name.capitalized)(\(paramList)); err != nil {
                        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
                        return
                    }
                    c.JSON(http.StatusOK, gin.H{"success": true})
            
            """
        } else {
            return """
                    result, err := service.\(method.name.capitalized)(\(paramList))
                    if err != nil {
                        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
                        return
                    }
                    c.JSON(http.StatusOK, result)
            
            """
        }
    }
    
    private static func convertToGoMethod(_ method: MethodInfo) -> String {
        let params = method.parameters.map { param in
            "\(param.name) \(swiftTypeToGo(param.type))"
        }.joined(separator: ", ")
        
        let contextParam = params.isEmpty ? "ctx context.Context" : "ctx context.Context, \(params)"
        let returnType = method.returnType == "Void" ? "error" : "(\(swiftTypeToGo(method.returnType)), error)"
        
        return "\(method.name.capitalized)(\(contextParam)) \(returnType)"
    }
    
    private static func swiftTypeToGo(_ swiftType: String) -> String {
        switch swiftType {
        case "String":
            return "string"
        case "Int":
            return "int"
        case "Double":
            return "float64"
        case "Bool":
            return "bool"
        case "Date":
            return "time.Time"
        case "Void":
            return ""
        default:
            if swiftType.hasSuffix("?") {
                let baseType = String(swiftType.dropLast())
                return "*" + swiftTypeToGo(baseType)
            }
            if swiftType.hasPrefix("[") && swiftType.hasSuffix("]") {
                let elementType = String(swiftType.dropFirst().dropLast())
                return "[]" + swiftTypeToGo(elementType)
            }
            return "*" + swiftType // Assume it's a struct pointer
        }
    }
}

// MARK: - Protocol Reflection and Parsing

class ProtocolParser {
    
    static func extractProtocols(from sourceFiles: [String]) -> [ProtocolInfo] {
        // This would use SourceKit or Swift AST parsing in a real implementation
        // For now, return mock data that represents what would be extracted
        
        return [
            ProtocolInfo(
                name: "UserService",
                methods: [
                    MethodInfo(
                        name: "getUser",
                        parameters: [ParameterInfo(name: "id", type: "String", isOptional: false)],
                        returnType: "User",
                        httpMethod: "GET",
                        path: "/{id}",
                        isAsync: true,
                        canThrow: true
                    ),
                    MethodInfo(
                        name: "createUser",
                        parameters: [ParameterInfo(name: "user", type: "CreateUserRequest", isOptional: false)],
                        returnType: "User",
                        httpMethod: "POST",
                        path: "/",
                        isAsync: true,
                        canThrow: true
                    )
                ],
                annotations: [
                    "service": "UserService",
                    "basePath": "/api/v1/users"
                ]
            )
        ]
    }
}

// MARK: - Build Integration

@main
struct BackendCodeGenerator {
    static func main() {
        let arguments = CommandLine.arguments
        
        guard arguments.count >= 2 else {
            print("Usage: BackendCodeGenerator <swift-source-directory> [output-directory]")
            exit(1)
        }
        
        let sourceDirectory = arguments[1]
        let outputDirectory = arguments.count > 2 ? arguments[2] : "./generated"
        
        print("Scanning Swift protocols in: \(sourceDirectory)")
        
        // In a real implementation, this would scan for .swift files
        let sourceFiles = scanSwiftFiles(in: sourceDirectory)
        let protocols = ProtocolParser.extractProtocols(from: sourceFiles)
        
        print("Found \(protocols.count) protocols to generate")
        
        let goCode = BackendGenerator.generateGoCode(from: protocols)
        
        // Write generated code
        let outputPath = "\(outputDirectory)/generated_services.go"
        do {
            try goCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Generated Go code written to: \(outputPath)")
        } catch {
            print("Error writing generated code: \(error)")
            exit(1)
        }
        
        // Generate additional files
        generateMakefile(outputDirectory: outputDirectory)
        generateDockerfile(outputDirectory: outputDirectory)
        generateReadme(outputDirectory: outputDirectory)
    }
    
    static func scanSwiftFiles(in directory: String) -> [String] {
        // Mock implementation - would actually scan filesystem
        return [
            "\(directory)/UserService.swift",
            "\(directory)/AuthService.swift"
        ]
    }
    
    static func generateMakefile(outputDirectory: String) {
        let makefile = """
        # Generated Makefile for Go backend
        
        .PHONY: build run test generate clean
        
        build:
        \tgo build -o bin/server ./cmd/server
        
        run: build
        \t./bin/server
        
        test:
        \tgo test ./...
        
        generate:
        \tswift run BackendCodeGenerator ../ios-app/Sources ./
        
        clean:
        \trm -rf bin/
        \trm -f generated_*.go
        
        docker-build:
        \tdocker build -t backend-service .
        
        docker-run:
        \tdocker run -p 8080:8080 backend-service
        """
        
        try? makefile.write(toFile: "\(outputDirectory)/Makefile", atomically: true, encoding: .utf8)
    }
    
    static func generateDockerfile(outputDirectory: String) {
        let dockerfile = """
        FROM golang:1.21-alpine AS builder
        
        WORKDIR /app
        COPY go.mod go.sum ./
        RUN go mod download
        
        COPY . .
        RUN go build -o server ./cmd/server
        
        FROM alpine:latest
        RUN apk --no-cache add ca-certificates
        WORKDIR /root/
        
        COPY --from=builder /app/server .
        
        EXPOSE 8080
        CMD ["./server"]
        """
        
        try? dockerfile.write(toFile: "\(outputDirectory)/Dockerfile", atomically: true, encoding: .utf8)
    }
    
    static func generateReadme(outputDirectory: String) {
        let readme = """
        # Generated Go Backend
        
        This backend service was generated from Swift protocol definitions.
        
        ## Getting Started
        
        ```bash
        # Build and run
        make run
        
        # Run tests
        make test
        
        # Regenerate from Swift protocols
        make generate
        
        # Docker
        make docker-build
        make docker-run
        ```
        
        ## API Endpoints
        
        The service implements the following endpoints based on your Swift protocols:
        
        - `GET /api/v1/users/{id}` - Get user by ID
        - `POST /api/v1/users` - Create new user
        - `PUT /api/v1/users/{id}` - Update user
        - `DELETE /api/v1/users/{id}` - Delete user
        - `GET /api/v1/users` - List users
        
        ## Development Workflow
        
        1. Modify Swift protocols in your iOS app
        2. Run `make generate` to update Go interfaces
        3. Implement the generated interfaces in Go
        4. Test and deploy
        
        Your Swift protocols are the single source of truth for the API contract.
        """
        
        try? readme.write(toFile: "\(outputDirectory)/README.md", atomically: true, encoding: .utf8)
    }
}

// MARK: - Package.swift Integration

/*
// Package.swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "APIContracts",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "APIContracts",
            targets: ["APIContracts"]
        ),
        .executable(
            name: "BackendCodeGenerator", 
            targets: ["BackendCodeGenerator"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        .target(
            name: "APIContracts",
            dependencies: []
        ),
        .executableTarget(
            name: "BackendCodeGenerator",
            dependencies: [
                "APIContracts",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "APIContractsTests",
            dependencies: ["APIContracts"]
        )
    ]
)
*/