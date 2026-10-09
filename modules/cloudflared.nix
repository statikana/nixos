{ ... }: {
    services.cloudflared = {
        enable = true;
        tunnels = {
            "8054cb48-cd44-4232-8cb1-fd0c7540c73a" = {
                credentialsFile = "/var/lib/cloudflared-creds/8054cb48-cd44-4232-8cb1-fd0c7540c73a.json";
                default = "http_status:404";
                ingress."app.peckhamr.com" = "http://localhost:8080";
            };
        };
    };
}
