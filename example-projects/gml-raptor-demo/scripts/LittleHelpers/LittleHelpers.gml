/// @function					is_between(val, lower_bound, upper_bound)
/// @description				test if a value is between lower and upper (both INCLUDING!)
/// @param {real/int} val
/// @param {real/int} lower_bound
/// @param {real/int} upper_bound
/// @returns {bool} y/n
function is_between(val, lower_bound, upper_bound) {
	return val >= lower_bound && val <= upper_bound;
}

/// @function					is_between_ex(val, lower_bound, upper_bound)
/// @description				test if a value is between lower and upper (both EXCLUDING!)
/// @param {real/int} val
/// @param {real/int} lower_bound
/// @param {real/int} upper_bound
/// @returns {bool} y/n
function is_between_ex(val, lower_bound, upper_bound) {
	return val > lower_bound && val < upper_bound;
}

/// @function					is_any_of(val)
/// @description				after val, specify any number of parameters.
///								determines if val is equal to any of them.
/// @param {any} val
/// @returns {bool}	y/n
function is_any_of(val) {
	for (var i = 1; i < argument_count; i++)
		if (val == argument[i]) return true;
	return false;
}

/// @function		percent(val, total)
/// @description	Gets, how many % "val" is of "total"
/// @param {real} val	The value
/// @param {real} total	100%
/// @returns {real}	How many % of total is val. Example: val 30, total 50 -> returns 60(%)
function percent(val, total) {
	return (val/total) * 100;
}

/// @function					percent_mul(of, total)
/// @description				Gets, how many % "of" is of "total" as multiplier (30,50 => 0.6)
/// @param {real} of
/// @param {real} total
/// @returns {real}	percent value as multiplier (0..1)
function percent_mult(of, total) {
	return (of/total);
}

/// @function					is_child_of(child, parent)
/// @description				True, if the child is parent or derived anywhere from parent.
/// @param {object_index} child An object instance or object_index of the child to analyze
/// @param {object} parent		The object_index (just the type) of the parent to find
/// @returns {bool}
#macro OBJECT_HAS_NO_PARENT	-100
function is_child_of(child, parent) {
	var to_find;
	if (instance_exists(child)) {
		to_find = child.object_index;
		if (IS_HTML || !instance_exists(parent)) {
			if (object_get_name(to_find) == object_get_name(parent)) return true;
		} else
			if (to_find == parent.object_index) return true;
	} else {
		to_find = child;
		if (IS_HTML) {
			if (object_get_name(to_find) == object_get_name(parent)) return true;
		} else
			if (child == parent) return true;
	}
	
	while (to_find != OBJECT_HAS_NO_PARENT && !object_is_ancestor(to_find, parent)) 
		to_find = object_get_parent(to_find);
	
	return to_find != OBJECT_HAS_NO_PARENT;
}

/// @function					name_of(_instance)
/// @description				If _instance is undefined, undefined is returned,
///								otherwise MY_NAME or object_get_name of the instance is returned,
///								depending on the _with_ref_id parameter.
///								To cover the undefined scenario, this function is normally used like this:
///								var instname = name_of(my_instance) ?? "my default";
/// @param {object_index} _instance	The instance to retrieve the name of.
function name_of(_instance, _with_ref_id = true) {
	if (_instance != undefined)
		with(_instance) return _with_ref_id ? MY_NAME : object_get_name(_instance.object_index);
	return undefined;
}

/// @function		run_delayed(owner, delay, func, data = undefined)
/// @description	Executes a specified function in <delay> frames from now.
///					Behind the scenes this uses the __animation_empty function which
///					is part of the ANIMATIONS ListPool, so if you clear all animations,
///					or use animation_run_ex while this is waiting for launch, 
///					you will also abort this one here.
///					Keep that in mind.
/// @param {instance} owner	The owner of the delayed runner
/// @param {int} delay		Number of frames to wait
/// @param {func} func		The function to execute
/// @param {struct} data	An optional data struct to be forwarded to func. Defaults to undefined.
/// @returns {Animation}	The animation processing the delay
function run_delayed(owner, delay, func, data = undefined) {
	var anim = __animation_empty(owner, delay, 0).add_finished_trigger(function(data) { data.func(data.args); });
	anim.data.func = func;
	anim.data.args = data;
	return anim;
}

/// @function		run_delayed_ex(owner, delay, func, data = undefined)
/// @description	Executes a specified function EXCLUSIVELY in <delay> frames from now.
///					Exclusively means in this case, animation_abort_all is invoked before
///					starting the delayed waiter.
///					Behind the scenes this uses the __animation_empty function which
///					is part of the ANIMATIONS ListPool, so if you clear all animations,
///					or use animation_run_ex while this is waiting for launch, 
///					you will also abort this one here.
///					Keep that in mind.
/// @param {instance} owner	The owner of the delayed runner
/// @param {int} delay		Number of frames to wait
/// @param {func} func		The function to execute
/// @param {struct} data	An optional data struct to be forwarded to func. Defaults to undefined.
/// @returns {Animation}	The animation processing the delay
function run_delayed_ex(owner, delay, func, data = undefined) {
	animation_abort_all(owner);
	return run_delayed(owner, delay, func, data);
}

/// @function		run_delayed_exf(owner, delay, func, data = undefined)
/// @description	Read _exf as "exclusive with finish"
///					Executes a specified function EXCLUSIVELY in <delay> frames from now.
///					Exclusively means in this case, animation_finish_all is invoked before
///					starting the delayed waiter.
///					Behind the scenes this uses the __animation_empty function which
///					is part of the ANIMATIONS ListPool, so if you clear all animations,
///					or use animation_run_ex while this is waiting for launch, 
///					you will also abort this one here.
///					Keep that in mind.
/// @param {instance} owner	The owner of the delayed runner
/// @param {int} delay		Number of frames to wait
/// @param {func} func		The function to execute
/// @param {struct} data	An optional data struct to be forwarded to func. Defaults to undefined.
/// @returns {Animation}	The animation processing the delay
function run_delayed_exf(owner, delay, func, data = undefined) {
	animation_finish_all(owner);
	return run_delayed(owner, delay, func, data);
}

/// @function		if_null(value, value_if_null)
/// @description	Tests if the specified value is undefined or noone, or,
///					if it is a string, is empty.
///					In any of those cases value_if_null is returned, otherwise
///					value is returned.
/// @param {any} value	The value to test
/// @param {any} value_if_null	the value to return, if value is null.
/// @returns {any}	value or value_if_null
function if_null(value, value_if_null) {
	if (value == undefined || value == noone)
		return value_if_null;
	if (is_string(value))
		return string_is_empty(value) ? value_if_null : value;
	return value;
}

/// @function		eq(inst1, inst2)
/// @description	Compare, whether two object instances are the same instance
///					Due to a html bug you can not simply compare inst1==inst2,
///					but you have to compare their ids instead.
function eq(inst1, inst2) {
	TRY return string(inst1.id)==string(inst2.id) CATCH return false; ENDTRY
}