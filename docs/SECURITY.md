Security
===============================================================================


Security context of the functions
------------------------------------------------------------------------------

Most of the functions of this extension are declared with the `SECURITY INVOKER`
tag.
This means that these functions are executed with the privileges of the user
that calls them. This is an important restriction.

This extension contains another few functions declared with the tag
`SECURITY DEFINER`.

