Add things that need to be done but don't completely pertain to the current topic. You can remove TODOs as they are done:

- One thing to flag: things like git.nix's commit identity are part of that shared base, so right now every user on a host — primary and extra — would get identical git name/email. If you want per-user identity or other overrides later, that's a small follow-up (a per-user override file layered on top of the shared one); didn't build it since it wasn't asked for. Let me know if you want that next.
