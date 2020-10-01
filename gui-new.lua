local flib_gui = {}

local elem_event_keys = {}
for key, id in pairs(defines.events) do
  if string.find(key, "gui") then
    elem_event_keys[string.gsub(key, "_gui", "")] = id
  end
end

local elem_style_keys = {
  -- gui = {readOnly = true},
  -- name = {readOnly = true},
  minimal_width = true,
  maximal_width = true,
  minimal_height = true,
  maximal_height = true,
  natural_width = true,
  natural_height = true,
  top_padding = true,
  right_padding = true,
  bottom_padding = true,
  left_padding = true,
  top_margin = true,
  right_margin = true,
  bottom_margin = true,
  left_margin = true,
  horizontal_align = true,
  vertical_align = true,
  font_color = true,
  font = true,
  top_cell_padding = true,
  right_cell_padding = true,
  bottom_cell_padding = true,
  left_cell_padding = true,
  horizontally_stretchable = true,
  vertically_stretchable = true,
  horizontally_squashable = true,
  vertically_squashable = true,
  rich_text_setting = true,
  hovered_font_color = true,
  clicked_font_color = true,
  disabled_font_color = true,
  pie_progress_color = true,
  clicked_vertical_offset = true,
  selected_font_color = true,
  selected_hovered_font_color = true,
  selected_clicked_font_color = true,
  strikethrough_color = true,
  horizontal_spacing = true,
  vertical_spacing = true,
  use_header_filler = true,
  color = true,
  -- column_alignments = {readOnly = true},
  single_line = true,
  extra_top_padding_when_activated = true,
  extra_bottom_padding_when_activated = true,
  extra_left_padding_when_activated = true,
  extra_right_padding_when_activated = true,
  extra_top_margin_when_activated = true,
  extra_bottom_margin_when_activated = true,
  extra_left_margin_when_activated = true,
  extra_right_margin_when_activated = true,
  stretch_image_to_widget_size = true,
  badge_font = true,
  badge_horizontal_spacing = true,
  default_badge_font_color = true,
  selected_badge_font_color = true,
  disabled_badge_font_color = true,
  width = true,
  height = true,
  padding = true,
  margin = true
}

local elem_read_only_keys = {
  name = true,
  direction = true,
  elem_type = true,
  column_count = true,
  tabs = true
}

function flib_gui.init()
  if global.__flib then
    global.__flib.gui = {players = {}}
  else
    global.__flib = {
      gui = {players = {}}
    }
  end
end

function flib_gui.register_handlers()
  for name, id in pairs(defines.events) do
    if string.find(name, "gui") then
      script.on_event(id, flib_gui.dispatch)
    end
  end
end

-- navigate a structure to build a GUI
local function recursive_build(parent, structure, refs, handlers, player_index, updater_name)
  -- process structure
  local elem
  local structure_type = structure.type
  if structure_type == "tab-and-content" then
    local tab, content
    refs, handlers, tab = recursive_build(
      parent,
      structure.tab,
      refs,
      handlers,
      player_index,
      updater_name
    )
    refs, handlers, content = recursive_build(
      parent,
      structure.content,
      refs,
      handlers,
      player_index,
      updater_name
    )
    parent.add_tab(tab, content)
  else
    -- create element
    elem = parent.add(structure)
    -- iterate over properties
    local elem_index = elem.index
    for key, value in pairs(structure) do
      if key ~= "type" and key ~= "children" then
        local event_id = elem_event_keys[key]
        if elem_style_keys[key] then
          elem.style[key] = value
        elseif event_id then
          flib_gui.add_handler(player_index, elem_index, event_id, value, updater_name)
          local elem_handlers = handlers[elem_index]
          if elem_handlers then
            elem_handlers[#elem_handlers + 1] = event_id
          else
            handlers[elem_index] = {event_id}
          end
        elseif key == "ref" then
          -- convert to array if it was shortcutted
          if type(value) == "string" then
            value = {value}
          end
          local len = #value
          local prev = refs
          for i = 1, len do
            local subkey = value[i]
            if i < len then
              if not prev[subkey] then
                prev[subkey] = {}
              end
              prev = prev[subkey]
            else
              prev[subkey] = elem
            end
          end
        elseif not elem_read_only_keys[key] then
          elem[key] = value
        end
      end
    end
    -- add children
    local children = structure.children
    if children then
      for i = 1, #children do
        refs, handlers = recursive_build(
          elem,
          children[i],
          refs,
          handlers,
          player_index,
          updater_name
        )
      end
    end
  end

  return refs, handlers, elem
end

function flib_gui.build(parent, updater_name, structures)
  local refs = {}
  local handlers = {}
  local player_index = parent.player_index or parent.player.index
  for i = 1, #structures do
    refs, handlers = recursive_build(
      parent,
      structures[i],
      refs,
      handlers,
      player_index,
      updater_name
    )
  end
  return refs, handlers
end

function flib_gui.dispatch(event_data)
  local element = event_data.element
  local player_index = event_data.player_index
  if not element or not player_index then return false end

  local player_data = global.__flib.gui.players[player_index]
  if not player_data then return false end

  local elem_index = element.index

  local elem_handlers = player_data.handlers[elem_index]
  if not elem_handlers then return false end

  local handler_data = elem_handlers[event_data.name]
  if handler_data then
    local updater_name = handler_data.updater_name
    local updater = flib_gui.updaters[updater_name]
    if not updater then
      error("Updater with the name ["..updater_name.."] does not exist.")
    end
    updater(handler_data.msg, event_data)
    return true
  else
    return false
  end
end

function flib_gui.add_handler(player_index, matcher, event_id, msg, updater_name)
  local players = global.__flib.gui.players

  local player_data = players[player_index]
  if not player_data then
    players[player_index] = {handlers = {}}
    player_data = players[player_index]
  end

  local player_handlers = player_data.handlers

  local elem_data = player_handlers[matcher]
  if not elem_data then
    player_handlers[matcher] = {}
    elem_data = player_handlers[matcher]
  end

  elem_data[event_id] = {
    msg = msg,
    updater_name = updater_name
  }
end

function flib_gui.remove_handler(player_index, matcher, event_id)
  local players = global.__flib.gui.players

  local player_data = players[player_index]
  if not player_data then return end

  local player_handlers = player_data.handlers
  local elem_data = player_handlers[matcher]
  if not elem_data then return end

  if event_id then
    elem_data[event_id] = nil
  end

  if not event_id or table_size(elem_data) == 0 then
    player_handlers[matcher] = nil
    if table_size(player_handlers) == 0 then
      players[player_index] = nil
    end
  end
end

flib_gui.updaters = {}

return flib_gui