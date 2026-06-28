# Contributing Guide

## Getting Started

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test your changes
5. Submit a pull request

## Code Style

### Terraform
- Format: `terraform fmt -recursive`
- Validate: `terraform validate`

### Shell Scripts
- Use `#!/bin/bash` shebang
- Set `set -euo pipefail` for error handling
- Use meaningful variable names
- Add comments for complex logic

### Python
- Follow PEP 8
- Use type hints
- Add docstrings

### Java
- Follow Google Java Style Guide
- Use Spring Boot conventions

### C#
- Follow Microsoft C# coding conventions
- Use async/await for I/O operations

## Testing

### Terraform
```bash
cd terraform
terraform validate
terraform fmt -check -recursive
```

### Python
```bash
python3 -m pytest scripts/python/tests/
```

### Java
```bash
cd applications/java-kafka-consumer
mvn test
```

### .NET
```bash
cd applications/dotnet-kafka-producer
dotnet test
```

## Documentation

- Update README.md for major changes
- Add comments to complex code
- Document new scripts in docs/

## Pull Request Process

1. Update documentation
2. Add tests for new features
3. Ensure all tests pass
4. Request review from maintainers

## Reporting Issues

Include:
- Terraform version
- kubectl version
- Error messages and logs
- Steps to reproduce
- Environment details

## Security

- Don't commit AWS credentials
- Use .env.local for sensitive data
- Report security issues privately
