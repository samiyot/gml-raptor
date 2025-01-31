/// @description scribblelize text

event_inherited();
gui_mouse = new GuiMouseTranslator();
mouse_is_over = false;
edges = new Edges(self);

nine_slice_data = new Rectangle(0, 0, sprite_width, sprite_height);

__startup_x					= x;
__startup_y					= y;
__startup_xscale			= image_xscale;
__startup_yscale			= image_yscale;
							
__last_sprite_index			= undefined;
__last_text					= "";
__scribble_text				= undefined;
__text_x					= 0;
__text_y					= 0;
							
__force_redraw				= false;

__disabled_surface			= undefined;
__disabled_surface_width	= 0;
__disabled_surface_height	= 0;

cleanup_disabled_surface = function() {
	if (__disabled_surface == undefined) return;
	
	__disabled_surface.Free();
	__disabled_surface			= undefined;
	__disabled_surface_width	= 0;
	__disabled_surface_height	= 0;
}

/// @function					force_redraw()
/// @description				force recalculate of all positions next frame
force_redraw = function() {
	__force_redraw = true;
}

/// @function					scribble_add_text_effects(scribbletext)
/// @description				called when a scribble element is created to allow adding custom effects.
///								overwrite (redefine) in child controls
/// @param {struct} scribbletext
scribble_add_text_effects = function(scribbletext) {
	// example: scribbletext.blend(c_blue, 1); // where ,1 is alpha
}

/// @function					draw_scribble_text()
/// @description				draw the text - redefine for additional text effects
draw_scribble_text = function() {
	__scribble_text.draw(__text_x, __text_y);
}

/// @function					__create_scribble_object(align, str)
/// @description				setup the initial object to work with
/// @param {string} align			
/// @param {string} str			
__create_scribble_object = function(align, str) {
	return scribble(align + str, MY_NAME)
			.starting_format(font_to_use == "undefined" ? scribble_font_get_default() : font_to_use, 
							 mouse_is_over ? text_color_mouse_over : text_color);
}

/// @function					__adopt_object_properties()
/// @description				copy blend, alpha, scale and angle from the object to the text
__adopt_object_properties = function() {
	if (adopt_object_properties == adopt_properties.alpha ||
		adopt_object_properties == adopt_properties.full) {
		__scribble_text.blend(image_blend, image_alpha);
	}
	if (adopt_object_properties == adopt_properties.full) {
		__scribble_text.transform(image_xscale, image_yscale, image_angle);
	}
}

/// @function					__finalize_scribble_text()
/// @description				add blend and transforms to the final text
__finalize_scribble_text = function() {
	if (adopt_object_properties != adopt_properties.none)
		__adopt_object_properties();
	scribble_add_text_effects(__scribble_text);
}

/// @function					__draw_self()
/// @description				invoked from draw or drawGui
__draw_self = function() {
	if (__force_redraw || x != xprevious || y != yprevious || __last_text != text || sprite_index != __last_sprite_index) {
		__force_redraw = false;

		if (sprite_index == -1)
			word_wrap = false; // no wrapping on zero-size objects
		
		__scribble_text = __create_scribble_object(scribble_text_align, text);
		__finalize_scribble_text();

		var nineleft = 0, nineright = 0, ninetop = 0, ninebottom = 0;
		var nine = -1;
		if (sprite_index != -1) {
			nine = sprite_get_nineslice(sprite_index);
			if (nine != -1 && nine.enabled) {
				nineleft = nine.left;
				nineright = nine.right;
				ninetop = nine.top;
				ninebottom = nine.bottom;
			}
			var distx = nineleft + nineright;
			var disty = ninetop + ninebottom;
		
			if (autosize) {
				image_xscale = max(__startup_xscale, (max(min_width, __scribble_text.get_width())  + distx) / sprite_get_width(sprite_index));
				image_yscale = max(__startup_yscale, (max(min_height,__scribble_text.get_height()) + disty) / sprite_get_height(sprite_index));
			}
			edges.update(nine);

			nine_slice_data.set(nineleft, ninetop, sprite_width - distx, sprite_height - disty);
			
		} else {
			// No sprite - update edges by hand
			edges.left = x;
			edges.top = y;
			edges.width  = text != "" ? __scribble_text.get_width() : 0;
			edges.height = text != "" ? __scribble_text.get_height() : 0;
			edges.right = edges.left + edges.width - 1;
			edges.bottom = edges.top + edges.height - 1;
			edges.center_x = x + edges.width / 2;
			edges.center_y = y + edges.height / 2;
			edges.copy_to_nineslice();
		}
		
		__text_x = edges.ninesliced.center_x + text_xoffset;
		__text_y = edges.ninesliced.center_y + text_yoffset;

		// text offset behaves differently when right or bottom aligned
		if      (string_pos("[fa_left]",   scribble_text_align) != 0) __text_x = edges.ninesliced.left   + text_xoffset;
		else if (string_pos("[fa_right]",  scribble_text_align) != 0) __text_x = edges.ninesliced.right  - text_xoffset;
		if      (string_pos("[fa_top]",    scribble_text_align) != 0) __text_y = edges.ninesliced.top    + text_yoffset;
		else if (string_pos("[fa_bottom]", scribble_text_align) != 0) __text_y = edges.ninesliced.bottom - text_yoffset;

		__last_text = text;
		__last_sprite_index = sprite_index;
	} else
		__finalize_scribble_text();

	if (sprite_index != -1) {
		if (!is_enabled) {
			__disabled_surface_width = sprite_width;
			__disabled_surface_height = sprite_height;
			shader_set(GrayScaleShader);
			draw_self();
			shader_reset();
		} else {
			image_blend = (mouse_is_over ? draw_color_mouse_over : draw_color);
			draw_self();
			image_blend = c_white;
		}
	}
	
	if (text != "") {
		if (is_enabled) {
			// cleanup so the next disable will create a new surface (contents might have changed)
			if (__disabled_surface != undefined) 
				cleanup_disabled_surface();
				
			draw_scribble_text();
		} else {
			if (__disabled_surface == undefined) {
				if (__disabled_surface_height == 0) {
					__disabled_surface_width = __scribble_text.get_width();
					__disabled_surface_height = __scribble_text.get_height();
				}
				__disabled_surface = new Canvas(__disabled_surface_width, __disabled_surface_height);
				var backx = __text_x;
				var backy = __text_y;
				__text_x -= x;
				__text_y -= y;
				__disabled_surface.Start();
				draw_scribble_text();
				__disabled_surface.Finish();
				__text_x = backx;
				__text_y = backy;
			}
			shader_set(GrayScaleShader);
			__disabled_surface.Draw(x - sprite_xoffset, y - sprite_yoffset);
			shader_reset();
		}
	}
}

