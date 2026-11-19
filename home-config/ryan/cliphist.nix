{ ... }: {
    services.cliphist = {
        enable = true;
        extraOptions = [
            "-max-items"
            "1000"
        ];
        allowImages = true;
    };
}
