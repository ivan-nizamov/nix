import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';

const EFFECT_NAME = 'amber-monochrome-shader';
const SHADER_SOURCE = `
uniform sampler2D tex;
varying vec2 cogl_tex_coord_in;

float dither2x2(vec2 position) {
    vec2 cell = mod(position, 2.0);

    if (cell.x < 1.0 && cell.y < 1.0)
        return 0.125;
    if (cell.x >= 1.0 && cell.y < 1.0)
        return 0.625;
    if (cell.x < 1.0 && cell.y >= 1.0)
        return 0.875;

    return 0.375;
}

void main() {
    vec4 color = texture2D(tex, cogl_tex_coord_in.st);
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    float threshold = dither2x2(gl_FragCoord.xy);
    float tone = floor(gray * 24.0 + threshold) / 24.0;
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
    this._target = global.stage ?? global.window_group ?? Main.layoutManager.uiGroup;
    if (!this._target) {
      return;
    }

    this._target.add_effect_with_name(EFFECT_NAME, new AmberMonochromeEffect());
  }

  disable() {
    if (!this._target) {
      return;
    }

    this._target.remove_effect_by_name(EFFECT_NAME);
    this._target = null;
  }
}
