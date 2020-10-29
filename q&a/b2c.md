# Azure AD B2C

## Using Graph API from B2C apps

Scenario: Use Azure AD B2C for user authentication and further use
Microsoft Graph for more deeper automations.

Let's look at the following architecture:

![Azure AD B2C authentication scenario](https://user-images.githubusercontent.com/2357647/97623887-f9669700-1a2e-11eb-85d1-c71c99660dd8.png)

Above architecture can be split in half:

- Left: User authentication using Azure AD B2C and for connecting to the backend api
    - Uses `Delegated permissions`
- Right: Backend api does further operations using Microsoft Graph
    - Uses `Application permissions`

Explanation for this split is following. B2C application permission view:

![B2C application permissions](https://user-images.githubusercontent.com/2357647/97622689-4c3f4f00-1a2d-11eb-93e4-1fa6f47c3d49.png)

If I try to add more delegated Microsoft Graph permissions see following comment on top of the dialog:

![Adding Microsoft Graph permissions](https://user-images.githubusercontent.com/2357647/97622819-785ad000-1a2d-11eb-8aa8-f5aaf3acd36c.png)

> Azure AD B2C only uses `offline_access` and `openid` delegated permissions

And after that there is link for [relevant documentation](https://docs.microsoft.com/en-us/azure/active-directory-b2c/microsoft-graph-get-started).

Key point being in here that you would leverage `Application permissions`
for rest of your Microsoft Graph operations.
