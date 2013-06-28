import "dart:html";
import "package:web_ui/web_ui.dart";
import "package:logging/logging.dart";
import "dart:math";
import "dart:async";
import "../s_p_impl.dart";

final _logger = new Logger("splitPanel");


/// Panel that provides (n-1) vertical splitters for n elements
class SPVPanel extends SPPanelBase { 

  // custom <class SPVPanel>

  List<String> get splitElementCssClasses => ['s-p-v-split-element'];

  IElement wrapElement(Element e) => new VElement(e);

  IElement createSplitter() => new VElement(new DivElement())
    ..element.classes = [ 's-p-v-splitter' ];

  IElement createGhostSplitter() => createSplitter()
    ..element.id = "${host.id}-ghost-splitter"
    ..element.classes.add('s-p-v-ghost-splitter');

  num distance(Point start, Point end) => (end.x - start.x);

  int get windowUsableLength => window.innerWidth;
  int get windowUsableContraLength => window.innerHeight;

  // end <class SPVPanel>
}



// custom <split_panel>

// end <split_panel>

