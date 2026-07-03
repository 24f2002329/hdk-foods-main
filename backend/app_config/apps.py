from django.apps import AppConfig


class AppConfigConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "app_config"

    def ready(self):
        import sys

        # Avoid running database tasks during tests, migrations, etc.
        if any(
            cmd in sys.argv
            for cmd in ["test", "migrate", "makemigrations", "showmigrations"]
        ):
            return

        try:
            from services.backup import schedule_backup_tasks

            schedule_backup_tasks()
        except ImportError:
            pass
