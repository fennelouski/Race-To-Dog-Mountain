#!/usr/bin/env python3
"""Render actual GameView geometry with digit/profile growth and concurrent overlays.

The temporary copy exposes only display inputs; no production source or preferences
are modified. ImageRenderer lays out ScrollView content but its bitmap is not used
as a screenshot assertion. Simulator UI tests supply visual evidence separately.
"""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
views = (root / 'Race to Dog Mountain/MountainViews.swift').read_text()
assert 'Double(game.scores[player])' in views
views = views.replace('Double(game.scores[player])', 'Double(LayoutProbe.scoreFixture ?? game.scores[player])')
seed = '        _computers = State(initialValue: saved?.computers ?? computers)'
assert views.count(seed) == 1
views = views.replace(seed, seed + '\n        _feedback = State(initialValue: LayoutProbe.events)')
mac = (root / 'Mac/MountainMacApp.swift').read_text().split('@main struct MountainMacApp:')[0]
template = (root / 'Tools/ReleaseChecks/pinned-layout-check.swift').read_text()
with tempfile.TemporaryDirectory(prefix='mountain-pinned-layout-') as temp:
    temp = Path(temp)
    combined = temp / 'Views.swift'; combined.write_text(views + '\n' + mac + '\n' + template)
    binary = temp / 'check'
    files = ['MountainGame.swift','MountainFonster.swift','MountainMatches.swift','MountainLibrary.swift','MountainFriends.swift','MountainSocialViews.swift','MountainScenery.swift','MountainBoard.swift']
    subprocess.run(['xcrun','swiftc','-parse-as-library','-D','DEBUG','-target',subprocess.check_output(['uname','-m'],text=True).strip()+'-apple-macos14.0',*[str(root / 'Race to Dog Mountain' / name) for name in files],str(combined),'-o',str(binary)],check=True)
    subprocess.run([str(binary),str(temp),'-MountainUITests','-MountainTestSession','3542D1DC-5175-48FC-A002-BC018376C0C0'],check=True)
