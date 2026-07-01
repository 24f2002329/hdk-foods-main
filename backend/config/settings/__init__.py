"""
config/settings/__init__.py
Delegates to the active environment settings module.

When DJANGO_SETTINGS_MODULE is set to ``config.settings`` (e.g. in CI),
this file acts as the settings module itself by importing everything from
base and then applying any environment-specific overrides via the
DJANGO_ENV environment variable.

Recognised DJANGO_ENV values
  development  – default for local dev  (also used in CI)
  production   – Azure / live server

Set DJANGO_SETTINGS_MODULE to one of:
    config.settings            (CI / generic; picks env via DJANGO_ENV)
    config.settings.development
    config.settings.production
    config.settings.local      (personal overrides, git-ignored)
"""

import os as _os

_env = _os.getenv("DJANGO_ENV", "development").lower()

if _env == "production":
    from config.settings.production import *  # noqa: F401, F403
elif _env == "local":
    from config.settings.local import *  # noqa: F401, F403
else:
    from config.settings.development import *  # noqa: F401, F403
