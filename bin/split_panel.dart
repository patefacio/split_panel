import "dart:io";
import "package:ebisu/ebisu_dart_meta.dart";
import "package:ebisu_web_ui/ebisu_web_ui.dart";
import "package:pathos/path.dart" as path;

main() {

  Options options = new Options();
  String here = path.absolute(options.script);
  String topDir = path.dirname(path.dirname(path.dirname(here)));
  ComponentLibrary lib = componentLibrary('split_panel')
    ..pubSpec.homepage = 'https://github.com/patefacio/split_panel'
    ..doc = '''Simple panel library supporting horizontal and vertical splitter panels'''
    ..rootPath = topDir
    ..examples = [
      example(id('vertical')),
      example(id('vertical_fit_to_window')),
      example(id('horizontal')),
      example(id('horizontal_fit_to_window')),
      example(id('horizontal_in_vertical')),
      example(id('vertical_in_horizontal')),
      example(id('combined')),
    ]
    ..libraries = [
      library('s_p_impl')
      ..imports = [ 
        'html',
        'math',
        'async',
        'package:web_ui/web_ui.dart'
      ]
      ..includeLogger = true
      ..parts = [
        part('s_p_panel_base')
        ..enums = [
          enum_('fit_to_method')
          ..doc = 'How/when is the panel resized'
          ..values = [
            id('fit_to_window'),
            id('fit_to_parent'),
            id('fit_to_self'),
          ],
        ]
        ..classes = [
          class_('s_p_panel_base')
          ..doc = 'Base for vertical and horizontal panels that provide splitters between the elements'
          ..isAbstract = true
          ..extend = 'WebComponent'
          ..members = [
            member('s_p_panel_descendents')
            ..doc = '''List of html children (recursive) which are either SPHPanel or SPVPanel
components.  The list is required to forward requests to resize on to any nested
split panels. Automatic resizing of panels are only triggered if the outermost
containing panel has [fitToMethod] of [FIT_TO_WINDOW]. In this case, on window
resize events, the resizing starts at that outermost panel with [fitToMethod] of
[FIT_TO_WINDOW] and cascades down to all contained SPPanelBase derivative
components.

'''
            ..access = IA
            ..type = 'List<SPPanelBase>'
            ..classInit = '[]',
            member('fit_to_method')
            ..doc = 'Determines how/when the split panel is resized'
            ..access = RO
            ..type = 'dynamic',
            member('panel')
            ..doc = 'Wrapped IElement for this panel'
            ..access = IA
            ..type = 'IElement',
            member('resize_timer')
            ..doc = '''Timer used to reduce work on panel resizing.
Approach outlined here: 

http://stackoverflow.com/questions/277759/html-onresizeend-event-or-equivalent-way-to-detect-end-of-resize
'''
            ..type = 'Timer'
            ..access = IA,
            member('parent_panel')
            ..doc = '''
When top panel is [FIT_TO_WINDOW] and this panel is of type [FIT_TO_PARENT] this
member caches the parent this panel is resized to'''
            ..access = IA
            ..type = 'IElement',
            member('split_elements')
            ..doc = 'List of *wrapped* split elements contained by this panel'
            ..access = IA
            ..type = 'List<SplitElement>'
            ..classInit = '[]',
            member('splitters')
            ..doc = 'List of splitters dividing the [SplitElements]'
            ..access = IA
            ..type = 'List<IElement>'
            ..classInit = '[]',
            member('total_splitter_length')
            ..doc = 'Caches the sum of splitter lengths'
            ..access = RO
            ..type = 'int'
            ..classInit = '0',
            member('ghost_splitter')
            ..doc = 'Hidden splitter, displayed when user begins to resize SplitElements within the panel'
            ..access = IA
            ..type = 'IElement',
            member('splitter_move_start')
            ..doc = '''Where was the mouse when the splitter move started - used to calculate deltas
for resizing SplitElements'''
            ..access = IA
            ..type = 'Point',
            member('moving_splitter')
            ..doc = 'When splitter move starts - the splitter responsible'
            ..access = IA
            ..type = 'IElement',
            member('start_total_scroll')
            ..doc = '''On start of move this is calculated to correctly position the ghost splitter
when SplitElements are partially scrolled out'''
            ..access = RO
            ..type = 'int',
            member('start_total_contra_scroll')
            ..doc = '''On start of move this is calculated to correctly position the ghost splitter
when SplitElements are partially scrolled out'''
            ..access = RO
            ..type = 'int',
            member('first_split_element')
            ..doc = '''During a move either the left (horizontal) or top (vertical) element divided by
the movingSplitter'''
            ..access = IA
            ..type = 'SplitElement',
            member('second_split_element')
            ..doc = '''During a move either the right (horizontal) or bottom (vertical) element divided
by the movingSplitter'''
            ..access = IA
            ..type = 'SplitElement',
            member('move_subscription')
            ..doc = '''A subscription intially paused, but activated on splitter moves to track how far
to move the ghost splitter'''
            ..access = IA
            ..type = 'StreamSubscription<MouseEvent>',
            member('z_index')
            ..doc = '''
Used to put ghost splitters above split elements as well as have inner panels be
higher order than those contained'''
            ..access = RO
            ..type = 'int',
          ],
          class_('i_element')
          ..ctorCustoms = ['']
          ..doc = '''
An element interface that wraps an Element and tracks concept of length and
contraLength for that element. The idea is, horizontal panels (i.e. panels with
horizontal splitters) can have their contained SplitElements resized with
splitters along one dimension - the height. Similarly, vertical panels can have
their contained SplitElements resized along the width dimension. The dimension
the IElement can be resized along is called its *length*. The other dimension is
called the *contraLength*. By implementing resize logic in terms of *length* and
*contraLength*, the same resizing logic can be used for horizontal and vertical
panels.
'''
          ..isAbstract = true
          ..members = [
            member('element')
            ..doc = 'Wrapped element'
            ..type = 'Element'
            ..ctors = [''],
          ],
          class_('h_element')
          ..doc = '''
Horizontal element, i.e. an element lined up vertically in a horizontal panel
with horizontal splitters. The length maps to height (i.e. the variable
dimension). Similarly, contraLength maps to width (i.e. the non-varying
dimension).
'''
          ..extend = 'IElement',
          class_('v_element')
          ..doc = '''
Vertical element, i.e. an element lined up horizontally in a vertical panel with
vertical splitters. The length maps to width (i.e. the variable
dimension). Similarly, contraLength maps to height (i.e. the non-varying
dimension).
'''

          ..extend = 'IElement',
          class_('split_element')
          ..doc = 'An item stored in a SPVPanel or SPHPanel'
          ..ctorCustoms = ['']
          ..members = [
            member('wrapper')
            ..doc ='''
Wrapper for the SplitElement. To get the desired effect, each SplitElement
stored in a panel are wrapped in an additional div. Doing this allows the
borders, padding and margins to kind of get out of the way in calculating
resizing. This technique was described in "Stylin\' with CSS" by Charles
Wyke-Smith.
'''
            ..type = 'IElement'
            ..ctors = [''],
            member('is_static')
            ..doc = '''
True if the SplitElement should not be resized when panel is resized. Specified
by user via data-s-p-static attribute.
'''
            ..type = 'bool',
            member('proportion')
            ..doc = '''
The percent of the panel allocated to non-static elements that this SplitElement
should get.
'''
            ..type = 'double',
          ],
        ]
      ]
    ]
    ..components = [
      component('s_p_v_panel')
      ..doc = 'Panel that provides (n-1) vertical splitters for n elements'
      ..imports = [
        'math',
        'async',
        '../s_p_impl.dart'
      ]
      ..htmlImports = [ 
      ]
      ..implClass = (class_('s_p_v_panel')
          ..extend = 'SPPanelBase'
          ..members = [
          ]),

      component('s_p_h_panel')
      ..doc = 'Panel that provides (n-1) horizontal splitters for n elements'
      ..imports = [
        'math',
        'async',
        '../s_p_impl.dart'
      ]
      ..htmlImports = [ 
      ]
      ..implClass = (class_('s_p_h_panel')
          ..extend = 'SPPanelBase'
          ..members = [
          ]),

    ]
    ..dependencies = [
    ];
  
  lib.generate();
    
}