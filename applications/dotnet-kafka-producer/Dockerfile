FROM mcr.microsoft.com/dotnet/sdk:8.0 as builder

WORKDIR /app
COPY . .

RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0

WORKDIR /app
COPY --from=builder /app/publish .

EXPOSE 5000

ENV ASPNETCORE_URLS=http://+:5000

ENTRYPOINT ["dotnet", "KafkaProducer.dll"]
