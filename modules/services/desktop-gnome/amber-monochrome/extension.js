import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';

const EFFECT_NAME = 'amber-monochrome-shader';
const SHADER_SOURCE = `
uniform sampler2D tex;
varying vec2 cogl_tex_coord_in;

void main() {
    vec4 color = texture2D(tex, cogl_tex_coord_in.st);
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    float tone = pow(gray, 1.1);
    vec3 amber = vec3(1.0, 0.72, 0.22) * tone;
    gl_FragColor = vec4(amber, color.a);
}
`;

const AmberMonochromeEffect = GObject.registerClass(
class AmberMonochromeEffect extends Clutter.ShaderEffect {
  _init() {
    super._init();
    this.set_shader_source(SHADER_SOURCE);
  }

  vfunc_paint_target(...args) {
    this.set_uniform_value('tex', 0);
    super.vfunc_paint_target(...args);
  }
});

export default class AmberMonochromeExtension extends Extension {
  enable() {
    this._targets = [
      global.window_group,
      Main.layoutManager.uiGroup,
    ].filter((actor, index, actors) => actor && actors.indexOf(actor) === index);

    for (const actor of this._targets) {
      actor.add_effect_with_name(EFFECT_NAME, new AmberMonochromeEffect());
    }
  }

  disable() {
    if (!this._targets) {
      return;
    }

    for (const actor of this._targets) {
      actor.remove_effect_by_name(EFFECT_NAME);
    }

    this._targets = null;
  }
}
