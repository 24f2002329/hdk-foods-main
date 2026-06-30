import re

def sanitize_text(val: str) -> str:
    """
    Sanitize text to strip script tags and other HTML tags to prevent XSS.
    """
    if isinstance(val, str):
        # Remove script tags and their content
        val = re.sub(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', '', val, flags=re.IGNORECASE)
        # Remove any remaining HTML tags
        val = re.sub(r'<[^>]+>', '', val)
        return val.strip()
    return val
