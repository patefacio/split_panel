import "dart:io";
import "package:web_ui/component_build.dart";

main() {
  build(new Options().arguments, 
    [
      "example/vertical/vertical.html",
      "example/vertical_fit_to_window/vertical_fit_to_window.html",
      "example/horizontal/horizontal.html",
      "example/horizontal_fit_to_window/horizontal_fit_to_window.html",
      "example/horizontal_in_vertical/horizontal_in_vertical.html",
      "example/vertical_in_horizontal/vertical_in_horizontal.html",
      "example/combined/combined.html"
    ]);
}
