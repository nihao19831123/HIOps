FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Copy self-contained application
COPY api/ /app/

RUN chmod +x /app/HIOps.Api

ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENV ASPNETCORE_ENVIRONMENT=Development

EXPOSE 8080

ENTRYPOINT ["/app/HIOps.Api"]
