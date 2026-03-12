import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import GObject from 'gi://GObject';
import St from 'gi://St';
import GLib from 'gi://GLib';

const SERVICE = 'lid-inhibit.service';
const FALLBACK_SYSTEMCTL = '/run/current-system/sw/bin/systemctl';
const decoder = new TextDecoder('utf-8');

function findSystemctl() {
  const fromPath = GLib.find_program_in_path('systemctl');
  if (fromPath) {
    return fromPath;
  }
  return FALLBACK_SYSTEMCTL;
}

function decodeOutput(bytes) {
  if (!bytes) {
    return '';
  }

  try {
    return decoder.decode(bytes).trim();
  } catch (_error) {
    return '';
  }
}

const LidInhibitIndicator = GObject.registerClass(
class LidInhibitIndicator extends PanelMenu.Button {
  _init() {
    super._init(0.0, 'Lid Ignore');

    this._systemctl = findSystemctl();
    this._icon = new St.Icon({
      icon_name: 'computer-laptop-symbolic',
      style_class: 'system-status-icon',
    });
    this.add_child(this._icon);

    this.connect('button-press-event', () => {
      this._toggle();
    });

    this._updateState();
    this._timeoutId = GLib.timeout_add_seconds(
      GLib.PRIORITY_DEFAULT,
      3,
      () => {
        this._updateState();
        return GLib.SOURCE_CONTINUE;
      }
    );
  }

  _spawnSync(argv) {
    try {
      const [ok, stdout, _stderr, _status] = GLib.spawn_sync(
        null,
        argv,
        null,
        GLib.SpawnFlags.SEARCH_PATH,
        null
      );
      if (!ok) {
        return null;
      }

      return decodeOutput(stdout);
    } catch (error) {
      logError(error, 'lid-inhibit: failed to run command');
      return null;
    }
  }

  _spawnAsync(argv) {
    try {
      GLib.spawn_async(
        null,
        argv,
        null,
        GLib.SpawnFlags.SEARCH_PATH,
        null
      );
    } catch (error) {
      logError(error, 'lid-inhibit: failed to spawn command');
    }
  }

  _isActive() {
    const output = this._spawnSync([
      this._systemctl,
      '--user',
      'is-active',
      SERVICE,
    ]);
    if (!output) {
      return null;
    }

    return output.trim() === 'active';
  }

  _setActive(active) {
    if (active === null) {
      this._icon.opacity = 150;
      this._icon.style = 'color: #f59e0b;';
      return;
    }

    if (active) {
      this._icon.opacity = 255;
      this._icon.style = 'color: #22c55e;';
    } else {
      this._icon.opacity = 120;
      this._icon.style = 'color: #e5e7eb;';
    }
  }

  _updateState() {
    const active = this._isActive();
    this._setActive(active);
  }

  _toggle() {
    const active = this._isActive();
    if (active === null) {
      return;
    }

    const action = active ? 'stop' : 'start';
    this._spawnAsync([
      this._systemctl,
      '--user',
      action,
      SERVICE,
    ]);

    GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
      this._updateState();
      return GLib.SOURCE_REMOVE;
    });
  }

  destroy() {
    if (this._timeoutId) {
      GLib.source_remove(this._timeoutId);
      this._timeoutId = null;
    }

    super.destroy();
  }
});

export default class LidInhibitExtension extends Extension {
  enable() {
    this._indicator = new LidInhibitIndicator();
    Main.panel.addToStatusArea('lid-inhibit', this._indicator);
  }

  disable() {
    if (this._indicator) {
      this._indicator.destroy();
      this._indicator = null;
    }
  }
}
