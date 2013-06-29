part of s_p_impl;

/// How/when is the panel resized
class FitToMethod { 
  static const FIT_TO_WINDOW = const FitToMethod._(0);
  static const FIT_TO_PARENT = const FitToMethod._(1);
  static const FIT_TO_SELF = const FitToMethod._(2);

  static get values => [
    FIT_TO_WINDOW,
    FIT_TO_PARENT,
    FIT_TO_SELF
  ];

  final int value;

  const FitToMethod._(this.value);

  String toString() { 
    switch(this) { 
      case FIT_TO_WINDOW: return "FIT_TO_WINDOW";
      case FIT_TO_PARENT: return "FIT_TO_PARENT";
      case FIT_TO_SELF: return "FIT_TO_SELF";
    }
  }

  static FitToMethod fromString(String s) { 
    switch(s) { 
      case "FIT_TO_WINDOW": return FIT_TO_WINDOW;
      case "FIT_TO_PARENT": return FIT_TO_PARENT;
      case "FIT_TO_SELF": return FIT_TO_SELF;
    }
  }


}

/// Base for vertical and horizontal panels that provide splitters between the elements
abstract class SPPanelBase extends WebComponent { 
  /// List of html children (recursive) which are either SPHPanel or SPVPanel
  /// components.  The list is required to forward requests to resize on to any nested
  /// split panels. Automatic resizing of panels are only triggered if the outermost
  /// containing panel has [fitToMethod] of [FIT_TO_WINDOW]. In this case, on window
  /// resize events, the resizing starts at that outermost panel with [fitToMethod] of
  /// [FIT_TO_WINDOW] and cascades down to all contained SPPanelBase derivative
  /// components.
  List<SPPanelBase> _sPPanelDescendents = [];
  dynamic _fitToMethod;
  /// Determines how/when the split panel is resized
  dynamic get fitToMethod => _fitToMethod;
  /// Wrapped IElement for this panel
  IElement _panel;
  /// Timer used to reduce work on panel resizing.
  /// Approach outlined here: 
  /// 
  /// http://stackoverflow.com/questions/277759/html-onresizeend-event-or-equivalent-way-to-detect-end-of-resize
  Timer _resizeTimer;
  /// When top panel is [FIT_TO_WINDOW] and this panel is of type [FIT_TO_PARENT] this
  /// member caches the parent this panel is resized to
  IElement _parentPanel;
  /// List of *wrapped* split elements contained by this panel
  List<SplitElement> _splitElements = [];
  /// List of splitters dividing the [SplitElements]
  List<IElement> _splitters = [];
  int _totalSplitterLength = 0;
  /// Caches the sum of splitter lengths
  int get totalSplitterLength => _totalSplitterLength;
  /// Hidden splitter, displayed when user begins to resize SplitElements within the panel
  IElement _ghostSplitter;
  /// Where was the mouse when the splitter move started - used to calculate deltas
  /// for resizing SplitElements
  Point _splitterMoveStart;
  /// When splitter move starts - the splitter responsible
  IElement _movingSplitter;
  int _startTotalScroll;
  /// On start of move this is calculated to correctly position the ghost splitter
  /// when SplitElements are partially scrolled out
  int get startTotalScroll => _startTotalScroll;
  int _startTotalContraScroll;
  /// On start of move this is calculated to correctly position the ghost splitter
  /// when SplitElements are partially scrolled out
  int get startTotalContraScroll => _startTotalContraScroll;
  /// During a move either the left (horizontal) or top (vertical) element divided by
  /// the movingSplitter
  SplitElement _firstSplitElement;
  /// During a move either the right (horizontal) or bottom (vertical) element divided
  /// by the movingSplitter
  SplitElement _secondSplitElement;
  /// A subscription intially paused, but activated on splitter moves to track how far
  /// to move the ghost splitter
  StreamSubscription<MouseEvent> _moveSubscription;
  int _zIndex;
  /// Used to put ghost splitters above split elements as well as have inner panels be
  /// higher order than those contained
  int get zIndex => _zIndex;

  // custom <class SPPanelBase>

  List<String> get splitElementCssClasses;

  /// Create appropriate horizontal or vertical splitter
  IElement createSplitter();

  /// Create appropriate horizontal or vertical ghost splitter
  IElement createGhostSplitter();

  /// The distance between two points on the *length* dimension
  num distance(Point start, Point end);

  /// Wraps an element with appropriate horizontal/vertical element
  IElement wrapElement(Element e);

  num get windowUsableLength;
  num get windowUsableContraLength;

  /// When resizing to parent, the parentPanel resized to
  IElement get parentPanel => (_parentPanel == null) ?
    _parentPanel = wrapElement(this.parentNode) : _parentPanel;

  bool get fullBodied => _fitToMethod == FitToMethod.FIT_TO_WINDOW;
  bool get fitToParent => _fitToMethod == FitToMethod.FIT_TO_PARENT;
  bool get fitToSelf => _fitToMethod == FitToMethod.FIT_TO_SELF;

  /// The length this panel should be resized to whenever resizing this panel
  num get _resizeToLength => (fullBodied? windowUsableLength : 
      (fitToParent? parentPanel.usableLength : _panel.usableLength));

  /// The contraLength this panel should be resized to whenever resizing this panel
  num get _resizeToContraLength => (fullBodied? windowUsableContraLength : 
      (fitToParent? parentPanel.usableContraLength : _panel.usableContraLength));

  /// After a manual splitter move, infer the new proportions
  void _inferElementProportions() {
    int totalLength = 0;
    var reproportionedElements = new Set<SplitElement>();
    _splitElements.forEach((splitElement) {
      if(!splitElement.isStatic) {
        totalLength += splitElement.length;
        reproportionedElements.add(splitElement);
      }
    });

    reproportionedElements.forEach((splitElement) {
      splitElement.proportion = splitElement.length/totalLength;
    });
  }

  _invariantTotalPanelLength() {
    var sayIt = _logger.info;
    if(totalPanelLength != _panel.length) {
      _logger.shout("ERR INV TotalPanelLength (id=${_panel.id}): " + 
          "totalPanelLength ${totalPanelLength} vs length ${_panel.length}");
      sayIt = _logger.shout;
    } else {
      _logger.info("INV TotalPanelLength HELD!!");
    }

    sayIt("...ResizeTo ${_resizeToLength} and contra ${_resizeToContraLength}");
    _splitElements.forEach((se) {
      sayIt("... (id=${se.id}): ${se.element.offset} l=${se.length} ul:${se.usableLength}");
    });
    _splitters.forEach((se) {
      sayIt("... (id=${se.id}): ${se.element.offset} l=${se.length} ul:${se.usableLength}");
    });
  }

  _invariantEqualContraLengths() {
    num len = _splitElements.first.contraLength;
    bool allGood = _splitElements.every((e) => e.contraLength == len);
    _logger.info("(id=${_panel.id}) position ${_panel.element.style.position}");    
    if(!allGood) {
      _logger.shout("ERR INV EqualContraLengths (id=${_panel.id}): Mismatch!!");
      _splitElements.forEach((se) {
        _logger.shout("...ERR INV EqualContraLengths (id=${se.id}): ${se.contraLength}");
      });
    } else {
      _logger.info("INV EqualContraLengths HELD!!");
    }
  }
  
  _allInvariants() {
    if(_debugModeInitialized) {
      _invariantTotalPanelLength();
      _invariantEqualContraLengths();
    }
  }

  /// Sum of all elements along the *length* dimension
  int get totalPanelLength =>
    _splitters.fold(0, (p, s) => p + s.length) +
    _splitElements.fold(0, (p, s) => p + s.wrapper.length);

  /// Maximum of all elements along the *contraLength* dimension
  int get panelContraLength =>
    _splitElements.fold(_splitters.fold(0, (p, s) => max(p, s.contraLength)), 
        (p,s) => max(p, wrapElement(s.wrapper.element.children.first).contraLength));

  /// Resize the elements in the panel, usually in response a change in the
  /// dimensions of the panel
  void _resizeElements([bool descending = true]) {
    int contraLength = _resizeToContraLength;
    int length = _resizeToLength;
    
    _splitters.forEach((splitter) => splitter.contraLength = contraLength);
    _splitElements.forEach((se) => se.contraLength = contraLength);

    _panel.contraLength = contraLength;
    _panel.length = length;

    _logger.info("Resizing ${_panel.id} to ${fitToMethod} l:${length} cl: ${contraLength}");

    int allocatableLength = length - totalSplitterLength;
    int totalStaticLength = 0;
    double totalPctSpecified = 0.0;

    int unsizedCount = 0;
    _splitElements.forEach((se) {
      totalPctSpecified += se.proportion;
      if(se.isStatic) {
        int staticLength = se.length;
        allocatableLength -= staticLength;
        totalStaticLength += staticLength;
      } else {
        if(se.proportion == 0)
          unsizedCount++;
      }
    });

    // Any unsized entries soak up the available length equally
    // They each get distribution amount
    int distribution = (unsizedCount > 0) ?
      (allocatableLength * (1.0 - totalPctSpecified)/unsizedCount).round() : 0;

    SplitElement slackElement = _splitElements.first;
    int maxAllocated = 0;
    int allocatedToSplitElements = 0;
    _splitElements.forEach((se) {
      int toBeAllocated = 0;
      // While iteration find largest length element to designate slack element
      if(!se.isStatic) {
        if(se.proportion == 0) {
          toBeAllocated = distribution;
        } else {
          var newLength = allocatableLength * se.proportion; 
          // In case the sum of pcts add up to less than the full amount, normalize to 1.0
          if(distribution == 0) {
            newLength /= totalPctSpecified;
          }
          int allocation = newLength.round();
          toBeAllocated = allocation;
        }

        if(toBeAllocated > maxAllocated) {
          maxAllocated = toBeAllocated;
          slackElement = se;
        }

        se.length = toBeAllocated;
        _logger.info("Allocated to (id=${se.id}) ${toBeAllocated} post ${se.length}");
        allocatedToSplitElements += toBeAllocated;
      }
    });

    int slack = allocatedToSplitElements + totalSplitterLength + totalStaticLength - length;

    assert(slack.abs() < 2);
    _logger.info("Total allocated $allocatedToSplitElements allocatable $allocatableLength and Slack is ${slack}");
    if(slack != 0) {
      slackElement.length = slackElement.length - slack; 
    }

    if(descending) {
      _resizeDescendents(descending);
      _resizeElements(!descending);
    }

    _inferElementProportions();
    _allInvariants();
  }

  void _resizeDescendents(bool descending) =>
    _sPPanelDescendents.forEach((descendent) => 
        descendent._resizeElements(descending));

  void _wrapContainedElements() {
    List<Element> unwrapped = new List.from(children);
    int count = 1;
    
    unwrapped.forEach((child) {
      var wrapper = wrapElement(new DivElement());
      wrapper.element.insertAdjacentElement('afterBegin', child)
        ..classes.addAll(splitElementCssClasses);
      SplitElement splitElement = new SplitElement(wrapper);
      if(child.id != null) 
        wrapper.element.id = "${child.id}-se-wrapper-${count++}";
      
      _splitElements.add(splitElement);
      children.add(splitElement.wrapper.element);
    });
  }

  void _addSplitters() {
    children.clear();
    int splitterContraLength = _panel.contraLength;
    int splitterCount = 1;
    _splitElements.getRange(0, _splitElements.length-1).forEach((se) {
      children.add(se.element);
      IElement splitter = createSplitter()
        ..contraLength = splitterContraLength
        ..element.id = "${host.id}-splitter-${splitterCount++}";
      _splitters.add(splitter);
      children.add(splitter.element);
    });
    _ghostSplitter = createGhostSplitter();
    
    children.add(_splitElements.last.element);
  }

  void _snapGhostToMovingSplitter() {
    _ghostSplitter.startOffset = _movingSplitter.startOffset - _startTotalScroll;
    _ghostSplitter.contraStartOffset = _movingSplitter.contraStartOffset - startTotalContraScroll;
    _ghostSplitter.contraLength = _movingSplitter.contraLength;
  }

  void _beginSplitterMove(IElement splitter, MouseEvent e) {
    _movingSplitter = splitter;

    int splitterIndex = _splitters.indexOf(_movingSplitter);
    _firstSplitElement = _splitElements[splitterIndex];
    _secondSplitElement = _splitElements[splitterIndex + 1];

    _splitterMoveStart = e.client;
    _startTotalScroll = _movingSplitter.totalScroll;
    _startTotalContraScroll = _movingSplitter.totalContraScroll;

    _moveSubscription.resume();
    children.add(_ghostSplitter.element);
    _snapGhostToMovingSplitter();

    // This prevents move of splitter from also highlighting/selecting composed text
    e.preventDefault();
    e.stopPropagation();
  }

  void _cleanUpSplitterMove() {
    _splitterMoveStart = null;
    _movingSplitter = null;
    _moveSubscription.pause();
    _firstSplitElement = null;
    _secondSplitElement = null;
    _ghostSplitter.element.remove();
  }

  void _endSplitterMove(MouseEvent e) {
    if(_movingSplitter != null) {
      _finalizeSplitterMove(e);
      _cleanUpSplitterMove();
      _inferElementProportions();
      _resizeElements();
    }
  }

  /// Determines the amount of the move and shifts that amout from either
  /// _firstSplitElement to _secondSplitElement or the reverse depending on
  /// direction of the move
  void _finalizeSplitterMove(MouseEvent e) {
    var delta = _ghostSplitter.startOffset - _movingSplitter.startOffset + _startTotalScroll;
    if(delta == 0) 
      return;
    _firstSplitElement.length = (_firstSplitElement.length + delta).round();
    _secondSplitElement.length = (_secondSplitElement.length - delta).round();
  }

  /// As mouse moves the ghost splitter must track it during a splitter move
  void _moveGhostSplitter(MouseEvent e) {
    num delta = distance(_splitterMoveStart, e.client);
    var firstLength = _firstSplitElement.length;
    var secondLength = _secondSplitElement.length;

    final int minLength = 2*sizeOfScroller;
    delta = delta<0? max(delta, minLength - firstLength) 
      : min(delta, secondLength - minLength);

    int newOffset = max(0,
        (_movingSplitter.startOffset + delta - _startTotalScroll).round());

    _ghostSplitter.startOffset = newOffset;
  }

  /// Set up the event handlers
  void _attachListeners() {

    // Create the subscription for mouse move events, but only track them when
    // handling splitter move events
    _moveSubscription = document.onMouseMove.listen((e) => _moveGhostSplitter(e));
    _moveSubscription.pause();
    document.onMouseUp.listen((e) => _endSplitterMove(e));

    // This prevents attempts to move the splitter for resize from being
    // viewed as a drag and drop event
    onDragStart.listen((e) => e.preventDefault());

    /// Capture the mouse down in each splitter to begin a move
    _splitters.forEach((splitter) =>
        splitter.element.onMouseDown.listen((e) => 
            _beginSplitterMove(splitter, e)));

    if(fullBodied) {
      window.onResize.listen((e) {
        if(_resizeTimer != null) 
          _resizeTimer.cancel();

        _resizeTimer = new Timer(new Duration(milliseconds: 100),
            () => _resizeElements());
      });
    }

  }

  /// Iterate over children recursively finding all panel descendents. On resize
  /// events those descendents are resized as well
  static void _findPanelDescendents(Element element, List<SPPanelBase> descendents) {
    element.children.forEach((child) {
      if(child.xtag is SPPanelBase) {
        descendents.add(child.xtag);
      } else {
        _findPanelDescendents(child, descendents);
      }
    });
  }

  /// Pull the fitToMethod from the dataset
  void _setFitToMethod() {
    switch(dataset['s-p-fit-to-method']) {
      case 'window': _fitToMethod = FitToMethod.FIT_TO_WINDOW; break;
      case 'parent': _fitToMethod = FitToMethod.FIT_TO_PARENT; break;
      default: _fitToMethod = FitToMethod.FIT_TO_SELF; break;
    }
  }

  /// Returns true if going up the chain of elements leads to another
  /// panel. When this is not the case (i.e. the panel is top most level) the
  /// fitToMethod is especially important since it determines if resizing occurs
  /// when the window is resized (i.e. top level panel is fitToWindow)
  bool hasSPPanelAncestor() {
    Element elm = this.parent;
    while(elm.parent != null) {
      if(elm.xtag is SPPanelBase) {
        return true;
      } else if(elm is BodyElement) {
        return false;
      }
      elm = elm.parent;
    }
    assert("Ancestor chain reached end without hitting body" == null);
  }

  void created() {
    //////////////////////////////////////////////////////////////////////
    // Uncomment for logging if not set up from above
    // _initDebugMode();
    //////////////////////////////////////////////////////////////////////
    _setFitToMethod();
    if(!hasSPPanelAncestor())
      _rootPanel = this;
  }

  void set zIndex(int i) {
    _panel.element.style.zIndex = "${i}";
    _logger.info("Set ${_panel.element.id} zindex to ${i} position ${_panel.element.style.position}");
    _splitElements.forEach((se) => se.zIndex = i);
    _splitters.forEach((splitter) => splitter.zIndex = i+1);
    _ghostSplitter.zIndex = i+1;
    _sPPanelDescendents.forEach((panel) => _panel.zIndex = i+2);
  }

  void inserted() {
    style.border = "0px";
    style.margin = "0px";
    style.padding = "0px";

    _findPanelDescendents(this, _sPPanelDescendents);
    _panel = wrapElement(this);
    _wrapContainedElements();
    _addSplitters();
    
    if(_splitters.length > 0) {
      _totalSplitterLength = _splitters.length * _splitters.first.length;
    }

    if(fullBodied) {
      document.body.style.margin = "0px";
      document.body.style.height = "100%";
      document.body.style.overflow = "auto";
      document.documentElement.style.height = "100%";
      document.documentElement.style.overflow = "auto";
      _resizeElements();
    } else {
      _panel.length = totalPanelLength;
      _panel.contraLength = panelContraLength;

      if(!_rootFullBodied)
        _resizeElements(false);
    }

    if(_rootPanel == this)
      zIndex = 1;

    _attachListeners();

    _logger.info("Inserted $this");
  }

  String toString() {
    List<String> entries = [ "(id=${host.id}) (${runtimeType}):" ];
    if(_sPPanelDescendents.length > 0)
      entries.add('''Panel Descendents of ${id}: 
  ${_sPPanelDescendents.map((desc) => desc.id).toList().join(',\n...')}''');

    _splitElements.forEach((e) =>
        entries.add('...(id=${e.id}) offset => ${e.element.offset}'));

    return entries.join('\n');
  }

  // end <class SPPanelBase>
}

/// An element interface that wraps an Element and tracks concept of length and
/// contraLength for that element. The idea is, horizontal panels (i.e. panels with
/// horizontal splitters) can have their contained SplitElements resized with
/// splitters along one dimension - the height. Similarly, vertical panels can have
/// their contained SplitElements resized along the width dimension. The dimension
/// the IElement can be resized along is called its *length*. The other dimension is
/// called the *contraLength*. By implementing resize logic in terms of *length* and
/// *contraLength*, the same resizing logic can be used for horizontal and vertical
/// panels.
///
abstract class IElement { 
  IElement(
    this.element
  ) {
    // custom <IElement>

    // end <IElement>
  }
  
  /// Wrapped element
  Element element;

  // custom <class IElement>

  set zIndex(int i) => element.style.zIndex = "${i}";

  get id => element.id;
  int get height => element.offsetHeight; 
  int get width => element.offsetWidth; 
  set height(num h) => setHeight(element, h);
  set width(num w) => setWidth(element, w);
  int get startOffset;
  set startOffset(int);
  int get length;
  int get usableLength;
  set length(int);
  int get totalScroll;
  int get totalContraScroll;
  int get contraStartOffset;
  set contraStartOffset(int);
  int get contraLength;
  set contraLength(int);

  String toString() => 'IElement (id=${element.id})';

  // end <class IElement>
}

/// Horizontal element, i.e. an element lined up vertically in a horizontal panel
/// with horizontal splitters. The length maps to height (i.e. the variable
/// dimension). Similarly, contraLength maps to width (i.e. the non-varying
/// dimension).
///
class HElement extends IElement { 

  // custom <class HElement>

  HElement(Element e) : super(e) {
  }

  int get startOffset => element.offsetTop;
  set startOffset(int offset) => setTop(element, offset);
  int get length => height;
  int get usableLength => element.clientHeight;
  set length(int len) => height = len;
  int get totalScroll => totalScrollTop(element);
  int get totalContraScroll => totalScrollLeft(element);
  int get contraStartOffset => element.offsetLeft;
  set contraStartOffset(int offset) => setLeft(element, offset);
  int get contraLength => width;
  set contraLength(int len) => width = len;
  int get usableContraLength => element.clientWidth;

  // end <class HElement>
}

/// Vertical element, i.e. an element lined up horizontally in a vertical panel with
/// vertical splitters. The length maps to width (i.e. the variable
/// dimension). Similarly, contraLength maps to height (i.e. the non-varying
/// dimension).
///
class VElement extends IElement { 

  // custom <class VElement>

  VElement(Element e) : super(e) {
  }

  int get startOffset => element.offsetLeft;
  set startOffset(int offset) => setLeft(element, offset);
  int get length => width;
  set length(int len) => width = len;
  int get usableLength => element.clientWidth;
  int get totalScroll => totalScrollLeft(element);
  int get totalContraScroll => totalScrollTop(element);
  int get contraStartOffset => element.offsetTop;
  set contraStartOffset(int offset) => setTop(element, offset);
  int get contraLength => height;
  set contraLength(int len) => height = len;
  int get usableContraLength => element.clientHeight;

  // end <class VElement>
}

/// An item stored in a SPVPanel or SPHPanel
class SplitElement { 
  SplitElement(
    this.wrapper
  ) {
    // custom <SplitElement>

    Element original = wrapper.element.children.first;
    bool originalHandlesScrolling = original.xtag is SPPanelBase;
    bool xScroller = canHaveXScroller(original) || originalHandlesScrolling;
    bool yScroller = canHaveYScroller(original) || originalHandlesScrolling;

    wrapper.element.style
      ..overflowX = (xScroller? "hidden" : "auto")
      ..overflowY = (yScroller? "hidden" : "auto")
      ..position = "relative"
      ..float = "left"
      ..border = "0px"
      ..margin = "0px"
      ..padding = "0px";

    var proportionAttr = original.dataset['s-p-proportion'];
    proportion = (proportionAttr != null)? double.parse(proportionAttr) : 0.0;
    var staticAttr = original.dataset['s-p-static'];
    isStatic = (staticAttr != null)? staticAttr == 'true' : false;
    assert(!isStatic || (isStatic && proportion == 0.0));

    // end <SplitElement>
  }
  
  /// Wrapper for the SplitElement. To get the desired effect, each SplitElement
  /// stored in a panel are wrapped in an additional div. Doing this allows the
  /// borders, padding and margins to kind of get out of the way in calculating
  /// resizing. This technique was described in "Stylin' with CSS" by Charles
  /// Wyke-Smith.
  IElement wrapper;
  /// True if the SplitElement should not be resized when panel is resized. Specified
  /// by user via data-s-p-static attribute.
  bool isStatic;
  /// The percent of the panel allocated to non-static elements that this SplitElement
  /// should get.
  double proportion;

  // custom <class SplitElement>

  Element get element => wrapper.element;
  get id => wrapper.id;
  get height => wrapper.height;
  get width => wrapper.width;
  set height(int h) => wrapper.height = h;
  set width(int w) => wrapper.width = w;

  set zIndex(int i) => wrapper.zIndex = i;

  get startOffset => wrapper.startOffset;
  set startOffset(int so) => wrapper.startOffset = so;
  int get length => wrapper.length;
  int get usableLength => wrapper.usableLength;
  set length(int l) => wrapper.length = l;

  int get totalScroll => wrapper.totalScroll;
  int get totalContraScroll => wrapper.totalContraScroll;

  get contraStartOffset => wrapper.contraStartOffset;
  set contraStartOffset(int so) => wrapper.contraStartOffset = so;
  int get contraLength => wrapper.contraLength;
  set contraLength(int i) => wrapper.contraLength = i;

  String toString() => 
    '''SplitElement: ${wrapper}
 proportion: $proportion
 static: $isStatic''';

  // end <class SplitElement>
}
// custom <part s_p_panel_base>

/// Top level panel
SPPanelBase _rootPanel;

/// True if top level panel is full bodied
bool get _rootFullBodied => _rootPanel.fullBodied;

/// Matches sizes specified in pixels
RegExp _sizePxRe = new RegExp(r'([\d.]+)px');

/// Returns number of pixels from a style size specification
double _pixels(String str) {
  double result = 0.0;
  var match = _sizePxRe.firstMatch(str);
  if(match != null)
    result = double.parse(match.group(1));
  return result;
}

/// Matches overflow items that allow for scrolling
RegExp _allowsScrolling = new RegExp(r'auto|scroll');

bool canHaveXScroller(Element e) =>
  _allowsScrolling.firstMatch(e.getComputedStyle().overflowX) != null;

bool canHaveYScroller(Element e) =>
  _allowsScrolling.firstMatch(e.getComputedStyle().overflowY) != null;

setLeft(Element elm, num left) => elm.style.left = "${left}px";
setTop(Element elm, num top) => elm.style.top = "${top}px";
setWidth(Element elm, num width) => elm.style.width = "${width}px";
setHeight(Element elm, num height) => elm.style.height = "${height}px";

int _sizeOfScroller;

/// Get and cache the size of scrollbars - approach outlined on SO:
/// http://stackoverflow.com/questions/986937/how-can-i-get-the-browsers-scrollbar-sizes
int get sizeOfScroller {
  if(_sizeOfScroller == null) {
    DivElement parent = new Element.html('''
<div style="width:50px;height:50px;overflow:auto">
  <div/>
</div>''');
    document.body.insertAdjacentElement('afterEnd', parent);
    var child = parent.children[0];
    var original = child.clientWidth;
    child.style.height = "99px";
    _sizeOfScroller = original - child.clientWidth;
    parent.remove();
  }
  return _sizeOfScroller;
}

int totalScrollLeft(Element e) {
  int result = e.scrollLeft;
  if(e.parentNode != null && e.parentNode is Element) {
    return result + totalScrollLeft(e.parentNode);
  }
  return result;
}

int totalScrollTop(Element e) {
  int result = e.scrollTop;
  if(e.parentNode != null && e.parentNode is Element) {
    return result + totalScrollTop(e.parentNode);
  }
  return result;
}

bool _debugModeInitialized = false;

void _initDebugMode() {
  if(!_debugModeInitialized) {
    Logger.root.onRecord.listen(new PrintHandler());
    Logger.root.level = Level.INFO;
    _debugModeInitialized = true;
    _logger.info("Logging is now on at level ${Logger.root.level}");
  }
}

// end <part s_p_panel_base>

