import time
import random
import logging
from functools import wraps

logger = logging.getLogger(__name__)


def retry_on_failure(
    max_retries=3, initial_backoff=1.0, backoff_factor=2.0, exceptions=(Exception,)
):
    """Decorator to retry a function call on specific exceptions using exponential backoff with jitter."""

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            retries = 0
            backoff = initial_backoff
            while True:
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    retries += 1
                    if retries > max_retries:
                        logger.error(
                            "Function '%s' failed after %d retries. Exception: %s",
                            func.__name__,
                            max_retries,
                            e,
                        )
                        raise

                    # Calculate delay with +/- 10% jitter
                    jitter = random.uniform(-0.1 * backoff, 0.1 * backoff)
                    sleep_time = max(0.1, backoff + jitter)

                    logger.warning(
                        "Function '%s' failed due to %s: %s. Retrying in %.2f seconds (Attempt %d/%d)...",
                        func.__name__,
                        e.__class__.__name__,
                        str(e),
                        sleep_time,
                        retries,
                        max_retries,
                    )

                    time.sleep(sleep_time)
                    backoff *= backoff_factor

        return wrapper

    return decorator
