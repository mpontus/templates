{
  description = "A collection of flake templates";

  outputs = { self }: {
    templates = {
      yarn-hello = {
        path = ./yarn-hello;
        description = "Yarn project template using yarn-plugin-nixify";
      };
    };
  };
}
