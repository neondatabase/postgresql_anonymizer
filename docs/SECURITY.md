Security
===============================================================================


Functions security context
------------------------------------------------------------------------------

Most functions of this extension are declared with the `SECURITY INVOKER` tag.
This means that theses functions are executed with the privileges of the user
that calls it. This is an important restriction.

This extension contains a few functions declared with the tag `SECURITY DEFINER`.

