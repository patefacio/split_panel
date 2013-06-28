# Split Panel

Basic components for providing horizontal or vertical splitters and
some liquid layout.

# Components

There are two components *x-s-p-v-panel* for vertical splitters and
*x-s-p-h-panel* for horizontal splitters. *Split Panels* contain two
types of entities: *Split Elements* and *Splitters*. *Splitters* are
placed between each *Split Element* child of the panel component. A
small amount of configuration is possible using html attributes. The
attributes can be used on the component instantiation as well as
contained children. The following html attributes are supported by the
component:
 
 * *data-s-p-fit-to-method* Specified on the panel itself. The allowed
   values are *window*, *parent* and *self*. Only the outermost panel
   may have this set to *window* which indicates the panel will
   grow/shrink with the window.

 * *data-s-p-static* Specified on the *Split Element* (i.e. children
    of the panel). Specifying this as *data-s-p-static="true"* will
    cause the size to be fixed during resizing.

 * *data-s-p-proportion* Specified on the *Split Element*
    (i.e. children of the panel). When a number is specified it
    represents the percentage of area allocated to all non-static
    elements that the decorated element should get.

# Potential Enhancements

 * Tests.
 * Include support for splitter collapsing.
 * Make it possible/easier for client code to style the splitter/ghost splitter.

# Authors
 * Daniel Davidson
