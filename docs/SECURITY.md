Security
===============================================================================


Functions security context
------------------------------------------------------------------------------

All function of this extension are declared with the `SECURITY INVOKER` tag. This
means that each function is executed with the privileges of the user that calls
it. This is an important restriction. This extension does not contained any
functions declared with the tag `SECURITY DEFINER`.
