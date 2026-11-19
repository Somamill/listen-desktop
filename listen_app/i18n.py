"""Interface language, separate from book and catalog language filters."""
import json
from functools import lru_cache
from pathlib import Path
from flask import request,g
from . import settings
LANGUAGES = {'en':'English','zh':'中文','es':'Español','ar':'العربية','id':'Bahasa Indonesia','pt':'Português','fr':'Français','ja':'日本語','ru':'Русский','de':'Deutsch'}
@lru_cache(maxsize=12)
def catalog(code):
    path = Path(__file__).with_name('locales') / (code+'.json')
    return json.loads(path.read_text()) if path.is_file() else {}
def locale():
    if hasattr(g, 'ui_locale'):return g.ui_locale
    chosen = settings.load().get('ui_language', 'system')
    if chosen in LANGUAGES:g.ui_locale=chosen;return chosen
    for language, quality in request.accept_languages:
        code = language.lower().split('-')[0]
        if quality and code in LANGUAGES:g.ui_locale=code;return code
    g.ui_locale='en'
    return 'en'
def translate(text):
    return catalog(locale()).get(text) or text
