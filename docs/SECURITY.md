Security
===============================================================================

Permissions
------------------------------------------------------------------------------

Here's an overview of what users can do depending on the role they have:

| Action                                   | Superuser | Owner | Masked Role |
| :--------------------------------------- | :-------: | :---: | :---------: |
| Create the extension                     |    Yes    |       |             |
| Drop the extension                       |    Yes    |       |             |
| Init the extension                       |    Yes    |       |             |
| Reset the extension                      |    Yes    |       |             |
| Configure the extension                  |    Yes    |  Yes  |             |
| Start dynamic masking                    |    Yes    |  Yes  |             |
| Stop  dynamic masking                    |    Yes    |  Yes  |             |
| Create a table                           |    Yes    |  Yes  |             |
| Declare a masking rule                   |    Yes    |  Yes  |             |
| Insert, delete, update a row             |    Yes    |  Yes  |             |
| Static Masking                           |    Yes    |  Yes  |             |
| Select the real data                     |    Yes    |  Yes  |             |
| Regular Dump                             |    Yes    |  Yes  |             |
| Select the masked data                   |    Yes    |  Yes  |     Yes     |
| Anonymous Dump                           |    Yes    |  Yes  |     Yes     |




Security context of the functions
------------------------------------------------------------------------------

Most of the functions of this extension are declared with the `SECURITY INVOKER`
tag.
This means that these functions are executed with the privileges of the user
that calls them. This is an important restriction.

This extension contains another few functions declared with the tag
`SECURITY DEFINER`.

