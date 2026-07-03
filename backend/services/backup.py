import os
import gzip
import shutil
import tempfile
import logging
from datetime import datetime
from django.conf import settings
from django.db import connection

logger = logging.getLogger(__name__)


def run_database_backup():
    """Dumps the database, compresses it, and uploads it to Firebase Storage."""
    logger.info("Starting database backup process...")
    db_engine = settings.DATABASES["default"]["ENGINE"]
    db_name = settings.DATABASES["default"]["NAME"]

    import firebase_admin
    from firebase_admin import storage

    if not firebase_admin._apps:
        logger.error("Firebase is not initialized. Cannot run database backup.")
        return False

    # Create temporary directory inside the workspace
    tmp_dir = os.path.join(settings.BASE_DIR, "tmp_backup")
    os.makedirs(tmp_dir, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    try:
        if "sqlite3" in db_engine:
            # SQLite backup
            backup_filename = f"db_backup_{timestamp}.sqlite3"
            backup_filepath = os.path.join(tmp_dir, backup_filename)

            # Use SQLite backup API (safest way to copy sqlite database without corruption)
            import sqlite3

            src_conn = connection.connection
            # If django is not currently holding a connection, connect directly
            if src_conn is None:
                src_conn = sqlite3.connect(db_name)

            dest_conn = sqlite3.connect(backup_filepath)
            with dest_conn:
                src_conn.backup(dest_conn)
            dest_conn.close()

            # Compress using gzip
            compressed_filepath = backup_filepath + ".gz"
            with open(backup_filepath, "rb") as f_in:
                with gzip.open(compressed_filepath, "wb") as f_out:
                    shutil.copyfileobj(f_in, f_out)

            upload_filepath = compressed_filepath
            dest_firebase_name = f"backups/db_{timestamp}.sqlite3.gz"

        else:
            # Fallback/alternative for PostgreSQL
            backup_filename = f"db_backup_{timestamp}.sql"
            backup_filepath = os.path.join(tmp_dir, backup_filename)
            compressed_filepath = backup_filepath + ".gz"

            # Read DB details
            db_user = settings.DATABASES["default"].get("USER", "")
            db_host = settings.DATABASES["default"].get("HOST", "")
            db_port = settings.DATABASES["default"].get("PORT", "")
            db_real_name = settings.DATABASES["default"].get("NAME", "")

            # Run pg_dump
            pg_dump_cmd = f"pg_dump -U {db_user} -h {db_host} -p {db_port} {db_real_name} > {backup_filepath}"
            os.system(pg_dump_cmd)

            # Compress
            with open(backup_filepath, "rb") as f_in:
                with gzip.open(compressed_filepath, "wb") as f_out:
                    shutil.copyfileobj(f_in, f_out)

            upload_filepath = compressed_filepath
            dest_firebase_name = f"backups/db_{timestamp}.sql.gz"

        # Upload compressed file to Firebase Storage
        bucket = storage.bucket()
        blob = bucket.blob(dest_firebase_name)

        with open(upload_filepath, "rb") as f:
            blob.upload_from_file(f, content_type="application/gzip")

        logger.info(
            "Database backup uploaded successfully to Firebase Storage as %s",
            dest_firebase_name,
        )
        return True

    except Exception as e:
        logger.error("Error during database backup: %s", e)
        return False

    finally:
        # Cleanup tmp files
        if os.path.exists(tmp_dir):
            shutil.rmtree(tmp_dir, ignore_errors=True)


def schedule_backup_tasks():
    """Ensure that the backup task is scheduled in Django Q."""
    try:
        from django_q.models import Schedule

        # We want to run this daily
        task_name = "services.backup.run_database_backup"

        # Check if the schedule already exists
        exists = Schedule.objects.filter(func=task_name).exists()
        if not exists:
            Schedule.objects.create(
                name="Daily Database Backup",
                func=task_name,
                schedule_type=Schedule.DAILY,
                repeats=-1,  # run indefinitely
            )
            logger.info("Scheduled database backup task in Django Q.")
    except Exception as e:
        logger.warning("Could not automatically schedule backup task: %s", e)
