# -*- coding: utf-8 -*-
"""Generates web/journal.html from docs/JOURNAL.md.

    Run from the top of the source tree:  make doc

    The Markdown file is the source; this only chooses the page furniture and
    says where the links in it should point once published.
"""
import os
from mdpage import build

REPO = 'https://github.com/hansolovkarlsson/Ariadne-Prolog/blob/main/'

build(mdfile='docs/JOURNAL.md',
      outfile='journal.html',
      title='Development Journal',
      prompt='?- journal',
      subtitle="How this interpreter got its shape: the one design decision "
               "everything else followed from, the three memory regions and the "
               "case they did not cover, documentation as a build product, and "
               "what four tutorial levels cost to write.",
      rewrite={
          'POSTMORTEM.md': os.environ.get('DOC_URL_POSTMORTEM') or 'postmortem.html',
          'CHANGELOG.md':  REPO + 'docs/CHANGELOG.md',
          'ROADMAP.md':    REPO + 'docs/ROADMAP.md',
          'README.md':     REPO + 'README.md',
      },
      retitle={
          'POSTMORTEM.md': 'The postmortem',
          'CHANGELOG.md':  'The changelog',
      },
      footer="Rendered from `docs/JOURNAL.md` in the source tree, which is "
             "the source of truth; `make doc` rebuilds this page and CI "
             "fails if the two no longer match.")
