import "dart:html";
import "package:web_ui/web_ui.dart";
import "package:logging/logging.dart";
import "dart:math";
import "dart:async";
import "../s_p_impl.dart";

final _logger = new Logger("splitPanel");


/// Panel that provides (n-1) horizontal splitters for n elements
class SPHPanel extends SPPanelBase { 

  // custom <class SPHPanel>

  List<String> get splitElementCssClasses => ['s-p-h-split-element'];

  IElement wrapElement(Element e) => new HElement(e);

  IElement createSplitter() => new HElement(new DivElement())
    ..element.classes = [ 's-p-h-splitter' ];

  IElement createGhostSplitter() => createSplitter()
    ..element.id = "${host.id}-ghost-splitter"
    ..element.classes.add('s-p-h-ghost-splitter');

  num distance(Point start, Point end) => (end.y - start.y);

  int get windowUsableLength => window.innerHeight;
  int get windowUsableContraLength => window.innerWidth;

  // end <class SPHPanel>
}



// custom <split_panel>
// end <split_panel>

