/*
	Utility methods to work with files.
	Requires juju's SNAP library and gml-raptor Buffers scripts to work.
	
	(c)2022- coldrock.games, @grisgram at github
	Please respect the MIT License for this library: https://opensource.org/licenses/MIT
*/

#macro __FILE_CACHE		global.__file_cache
__FILE_CACHE = {};

/// @function					file_clear_cache()
/// @description				clears the entire file cache
function file_clear_cache() {
	__FILE_CACHE = {};
}

/// @function				__ensure_file_cache()	
/// @description			ensures, the global cache exists
function __ensure_file_cache() {
	if (!variable_global_exists("__file_cache"))
		__FILE_CACHE = {};
}

/// @function					file_read_text_file_absolute(filename, remove_utf8_bom = true, add_to_cache = false)
/// @param {string} filename	The name (full path) of the file to read
/// @param {bool=true} remove_utf8_bom	If true (default) then the UTF8 ByteOrderMark will be removed (which is what you normally want)
/// @param {bool=false} add_to_cache	If true, the contents will be kept in a cache for later loads
/// @returns {string}			The contents of the file or undefined is something went wrong.
/// @description				reads an entire file and returns the contents as string
///								checks whether the file exists, and if not, an empty string is returned.
///								crashes, if the file is not a text file
function file_read_text_file_absolute(filename, remove_utf8_bom = true, add_to_cache = false) {
	__ensure_file_cache();
	
	if (variable_struct_exists(__FILE_CACHE, filename)) {
		log(sprintf("Cache hit for file '{0}'", filename));
		return variable_struct_get(__FILE_CACHE, filename);
	}
	
	var file = undefined;
	TRY
		log("Loading text file " + filename);
	    var _buffer = buffer_load(filename);
		var bufsize = buffer_get_size(_buffer);
		log($"Loaded {bufsize} bytes from file");
		var _string = undefined;
		if (bufsize > 0) {
		    if (remove_utf8_bom && (buffer_get_size(_buffer) >= 4) && (buffer_peek(_buffer, 0, buffer_u32) & 0xFFFFFF == 0xBFBBEF))
		    {
		        buffer_seek(_buffer, buffer_seek_start, 3);
		    }
    
		    _string = buffer_read(_buffer, buffer_string);
		    buffer_delete(_buffer);
	
			if (add_to_cache) {
				log(sprintf("Added file '{0}' to cache", filename));
				variable_struct_set(__FILE_CACHE, filename, _string);
			}
		}
	    return _string;
	CATCH return undefined; 
	ENDTRY
}

/// @function					file_read_text_file(filename, remove_utf8_bom = true, add_to_cache = false)
/// @param {string} filename	The name (relative path starting in working_directory) of the file to read
/// @param {bool=true} remove_utf8_bom	If true (default) then the UTF8 ByteOrderMark will be removed (which is what you normally want)
/// @param {bool=false} add_to_cache	If true, the contents will be kept in a cache for later loads
/// @description				reads an entire file and returns the contents as string
///								checks whether the file exists, and if not, an empty string is returned.
///								crashes, if the file is not a text file
function file_read_text_file(filename, remove_utf8_bom = true, add_to_cache = false) {
	return file_read_text_file_absolute(working_directory + filename, remove_utf8_bom, add_to_cache);
}

/// @function					file_write_text_file(filename, text)
/// @param {string} filename	The name (relative path starting in working_directory) of the output file
/// @param {string} text		The string to write out to the file
/// @returns {bool}				true, if the save succeeded, otherwise false.
/// @description				Saves a given text as a plain text file. Can write any string, not only json.
function file_write_text_file(filename, text) {
	__ensure_file_cache();
	TRY
		var buffer = buffer_create(string_byte_length(text) + 1, buffer_fixed, 1);
		buffer_write(buffer, buffer_string, text);
		buffer_save(buffer, working_directory + filename);
		buffer_delete(buffer);
		if (variable_struct_exists(__FILE_CACHE, filename)) {
			log(sprintf("Updated cache for file '{0}'", filename));
			variable_struct_set(__FILE_CACHE, filename, text);
		}
		return true;
	CATCH return false; ENDTRY
}

/// @function					file_write_struct(filename, struct, cryptkey = "")
/// @param {string} filename	The name (relative path starting in working_directory) of the output file
/// @param {struct} struct		The struct to write out to a json file
/// @param {string=""} cryptkey	Optional key to encrypt the file
/// @returns {bool}				true, if the save succeeded, otherwise false.
/// @description				Saves a given struct to a file, optionally encrypted
function file_write_struct(filename, struct, cryptkey = "") {
	if (cryptkey == "")
		return file_write_struct_plain(filename, struct)
	else
		return file_write_struct_encrypted(filename, struct, cryptkey);
}

/// @function					file_read_struct(filename, cryptkey = "", add_to_cache = false)
/// @description				Reads a given struct from a file, optionally encrypted
/// @param {string} filename	The name (relative path starting in working_directory) of the input file
/// @param {string=""} cryptkey	Optional key to encrypt the file
/// @param {bool=false} add_to_cache	If true, the contents will be kept in a cache for later loads
/// @returns {struct}			The json_decoded struct.
function file_read_struct(filename, cryptkey = "", add_to_cache = false) {
	if (cryptkey == "")
		return file_read_struct_plain(filename, add_to_cache);
	else
		return file_read_struct_encrypted(filename, cryptkey, add_to_cache);
}

/// @function					file_write_struct_plain(filename, struct)
/// @param {string} filename	The name (relative path starting in working_directory) of the output file
/// @param {struct} struct		The struct to write out to a json file
/// @returns {bool}				true, if the save succeeded, otherwise false.
/// @description				Saves a given struct as a plain text json file. This json is NOT "user friendly" formatted!
///								To create a user-friendly json use the SNAP library (https://github.com/JujuAdams/SNAP)
///								and the function SnapToJSON with the second parameter (_pretty) set to true to get a json string
///								and then send this json string to file_write_text_file(...).
function file_write_struct_plain(filename, struct) {
	__ensure_file_cache();
	TRY
		log("Saving plain text struct to " + filename);
		file_write_text_file(filename, SnapToJSON(struct, true));
		if (variable_struct_exists(__FILE_CACHE, filename)) {
			log(sprintf("Updated cache for file '{0}' (struct)", filename));
			variable_struct_set(__FILE_CACHE, filename, SnapDeepCopy(struct));
		}
		return true;
	CATCH return false; ENDTRY
}

/// @function			file_read_struct_plain(filename, add_to_cache = false)
/// @description		Loads the contents of the file and tries to parse it as struct.
///						Load is done synchronously.
///						If you deal with large files here, consider using coroutines.
/// @param {string} filename	Relative path inside the working_folder where to find the file
/// @param {bool=false} add_to_cache	If true, the contents will be kept in a cache for later loads
/// @returns {struct}			The json_decoded struct or undefined if something went wrong.
function file_read_struct_plain(filename, add_to_cache = false) {
	__ensure_file_cache();
	if (file_exists(working_directory + filename)) {
		if (variable_struct_exists(__FILE_CACHE, filename)) {
			log(sprintf("Cache hit for file '{0}'", filename));
			return SnapDeepCopy(variable_struct_get(__FILE_CACHE, filename));
		}
		TRY
			log("Loading plain text struct from " + filename);
			var contents = file_read_text_file(filename);
			log(sprintf("Read {0} characters from file", (string_is_empty(contents) ? "0" : string_length(contents))));
			var rv = undefined;
			if (!string_is_empty(contents)) {
				var indata = SnapFromJSON(contents);
				rv = __file_reconstruct_root(indata);
				if (add_to_cache) {
					log(sprintf("Added file '{0}' to cache (struct)", filename));
					variable_struct_set(__FILE_CACHE, filename, SnapDeepCopy(rv));
				}
			}
			return rv;
		CATCH return undefined;	ENDTRY
	}
	return undefined;
}

/// @function			file_write_struct_encrypted(filename, struct, cryptkey)
/// @description		Encrypts the binary representation of the given struct with a key
///						and saves this to a file. Save is done synchronously.
///						If you deal with large files here, consider using coroutines.
/// @param {string} filename	Relative path inside the working_folder where to put the file
/// @param {struct}	struct		The struct to persist
/// @param {string} cryptkey	A (hopefully) long string that makes the crypt mask
/// @returns {bool}				true, if the save succeeded, otherwise false.
function file_write_struct_encrypted(filename, struct, cryptkey) {
	__ensure_file_cache();
	TRY
		log("Saving encrypted struct to " + filename);
		var len = SnapBufferMeasureBinary(struct);
		var buffer = buffer_create(len, buffer_grow, 1);
		buffer_fill(buffer, 0, buffer_u8, 0, len);
		buffer = SnapBufferWriteBinary(buffer, struct);
		encrypt_buffer(buffer, cryptkey);
		buffer_save(buffer, working_directory + filename);
		buffer_delete(buffer);
		if (variable_struct_exists(__FILE_CACHE, filename)) {
			log(sprintf("Updated cache for file '{0}' (encrypted struct)", filename));
			variable_struct_set(__FILE_CACHE, filename, SnapDeepCopy(struct));
		}
		return true;
	CATCH return false; ENDTRY
}

/// @function			file_read_struct_encrypted(filename, cryptkey, add_to_cache = false)
/// @description		Decrypts the data in the specified file with the specified key.
///						Load is done synchronously.
///						If you deal with large files here, consider using coroutines.
/// @param {string} filename	Relative path inside the working_folder where to find the file
/// @param {string} cryptkey	The same key that has been used to encrypt the file.
/// @param {bool=false} add_to_cache	If true, the contents will be kept in a cache for later loads
/// @returns {struct}			The decrypted struct.
function file_read_struct_encrypted(filename, cryptkey, add_to_cache = false) {	
	__ensure_file_cache();
	if (file_exists(working_directory + filename)) {
		if (variable_struct_exists(__FILE_CACHE, filename)) {
			log(sprintf("Cache hit for file '{0}' (buffer deep copy)", filename));
			return SnapDeepCopy(variable_struct_get(__FILE_CACHE, filename));
		}
		TRY
			log("Loading encrypted struct from " + filename);
			var buffer = buffer_load(working_directory + filename);
			var bufsize = buffer_get_size(buffer);
			log(sprintf("Read {0} bytes into the buffer", bufsize));
			var rv = undefined;
			if (bufsize > 0) {
				encrypt_buffer(buffer, cryptkey);
				var indata = SnapBufferReadBinary(buffer, 0);
				rv = __file_reconstruct_root(indata);
				buffer_delete(buffer);
		
				if (add_to_cache) {
					log(sprintf("Added file '{0}' to cache (encrypted struct)", filename));
					variable_struct_set(__FILE_CACHE, filename, SnapDeepCopy(rv));
				}
			}
			return rv;
		CATCH return undefined; ENDTRY
	}
	return undefined;
}

/// @function		file_list_directory(wildcard, attributes = 0)
/// @description	list all matching files from a directory in an array
/// @param {string} wildcard	Pattern to search (like *.*)
/// @param {string} attributes	attr constants according to yoyo manual
///                             https://manual-en.yoyogames.com/#t=GameMaker_Language%2FGML_Reference%2FFile_Handling%2FFile_System%2Ffile_attributes.htm
/// @returns {array}			The list of existing files
function file_list_directory(wildcard, attributes = 0) {
	var rv = [];
	var f = file_find_first(wildcard, attributes);
	while (f != "") {
		array_push(rv, f);
		f = file_find_next();
	}
	file_find_close();
	return rv;
}

#region CONSTRUCTOR REGISTRATION
/// @function		__file_get_constructed_class(from)
function __file_get_constructed_class(from) {
	var rv = undefined;
	if (variable_struct_exists(from, __CONSTRUCTOR_NAME)) {
		var constname = from[$ __CONSTRUCTOR_NAME];
		//log(sprintf("Constructing '{0}'", constname));
		var class = asset_get_index(constname);
		rv = new class();
		if (variable_struct_exists(rv, __INTERFACES_NAME)) {
			var interfaces = rv[$ __INTERFACES_NAME];
			for (var i = 0, len = array_length(interfaces); i < len; i++)
				with(rv) implement(interfaces[@i]);
		}
	} else {
		rv = {};
	}
	return rv;
}

/// @function		__file_reconstruct_root(from)
function __file_reconstruct_root(from) {
	var rv = __file_get_constructed_class(from);
	__file_reconstruct_class(rv, from);
	return rv;
}

/// @function		__file_reconstruct_class(into, from)
/// @description	reconstruct a loaded data struct through its constructor
///					if the constructor is known.
function __file_reconstruct_class(into, from) {
	var names = variable_struct_get_names(from);
	
	with (into) {
		for (var i = 0; i < array_length(names); i++) {
			var name = names[i];
			var member = from[$ name];
			if (is_struct(member)) {
				var classinst = __file_get_constructed_class(member);
				self[$ name] = classinst;
				__file_reconstruct_class(classinst, member);
			} else if (is_array(member)) {
				for (var a = 0; a < array_length(member); a++) {
					var amem = member[@ a];
					if (is_struct(amem)) {
						var classinst = __file_get_constructed_class(amem);
						member[@ a] = classinst;
						__file_reconstruct_class(classinst, amem);
					}
				}
				self[$ name] = from[$ name];
			} else
				self[$ name] = from[$ name];
		}
	}
}

#endregion