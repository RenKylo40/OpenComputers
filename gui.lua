local component = require("component")
local gpu = component.gpu
local unicode = require("unicode")
local pull_e = require('event').pull
w, h = gpu.getResolution()

local colors = {
                  ['0'] = 0x0000, ['1'] = 0x0000AA, ['2'] = 0x00AA00, ['3'] = 0x00AAAA,
                  ['4'] = 0xAA0000, ['5'] = 0xAA00AA, ['6'] = 0xFFAA00, ['7'] = 0xAAAAAA,
                  ['8'] = 0x555555, ['9'] = 0x5555FF, ['a'] = 0x55FF55, ['b'] = 0x00FFFF,
                  ['c'] = 0xFF5555, ['d'] = 0xFF55FF, ['e'] = 0xFFFF55, ['f'] = 0xFFFFFF,
               }
local player = ""
buttons = {}
-- Настройки
local NAME = "Bubblegum Casino"

-- выравнивание по центру
function alignCenter(x, y, width, height)
  if x == nil then x = w end
  if y == nil then y = h end
  if width + 2 <= w and height + 2 <= h then
    local a = w/2 - width/2
    local b = h/2 - height/2
    return {a + 1, b + 1}
  end
  return {1, 1}
end

function formatText(text)
  text = text:gsub("<player>", player)
  text = text:gsub("<name>", NAME)
  return text
end

function calc(exp, width, height)
  if type(tonumber(exp)) == 'number' then
    return exp
  else
    exp = exp:gsub("parentX", width)
    exp = exp:gsub("parentY", height)
    local number = load("return "..exp)()
    return number
  end
end

function colorsCount(text)
  local colors_count = 0
  for i in text:gmatch(text, "&") do
    colors_count = (colors_count + 2)
  end
  return colors_count
end

-- рисуем пиксель
function drawPixel(x, y, color)
  gpu.setBackground(color)
  gpu.set(x, y, " ")
end

function drawRect(x, y, width, height, color, border)
  if width == "full" then
    width = w
  end
  if height == "full" then
    height = w
  end
  if x == "center" then
    x = alignCenter(_, _, width, 1)[1]
  end
  if y == "center" then
    y = alignCenter(_, _, 1, height)[2]
  end
  gpu.setBackground(color)
  gpu.fill(x, y, width, height, " ")
  -- Рамка
  if border == true then
    drawRect(x, y, width, height, color)
    drawText(x, y, 0x2b2b2b, "┌")
    drawText(x + width - 1, y, 0x2b2b2b, "┐")
    drawText(x, y + height - 1, 0x2b2b2b, "└")
    drawText(x + width - 1, y + height - 1, 0x2b2b2b, "┘")
    local str = ""
    for i = 1, width - 2 do
      str = str.."─"
    end
    drawText(x + 1, y, 0x2b2b2b, str)
    drawText(x + 1, y + height - 1, 0x2b2b2b, str)
  end
end

function drawImage(img)
  for i = 1, #img do
    drawPixel(img[i][1],img[i][2],img[i][3])
  end
end

function drawText(x, y, color, text)
  -- Центрируем
  if x == "center" then
    x = alignCenter(_, _, (#text + colorsCount(text)) / 2, 1)[1]
  end
  -- Красим текст
  if text:match("&") then
    local offset = 0
    for i = 1, unicode.len(text) do
      if unicode.sub(text, i, i) == "&" then
        gpu.setForeground(colors[unicode.sub(text, i + 1, i + 1)])
      elseif unicode.sub(text, i - 1, i - 1) ~= "&" then
        local _, _, bg = gpu.get(x + offset, y)
        gpu.setBackground(bg)
        gpu.set(x + offset, y, unicode.sub(text, i,i))
        offset = offset + 1
      end
    end
  else
    gpu.setForeground(color)
    gpu.set(x, y, text)
  end
end

function drawLine(x, y, width, color)
  gpu.setForeground(color)
  if x == "center" then
    x = alignCenter(_, _, width, 1)[1]
  end
  local line = ""
  for i = 1, width do
    line = line.."‒" -- ─
  end
  drawText(x, y, color, line)
end

function drawButton(x, y, width, height, bg, color, border, text, action)
  if x == "center" then
    x = alignCenter(_, _, width, 1)[1]
  end
  buttons[#buttons + 1] = {['x'] = x, ['y'] = y, ['width'] = width, ['height'] = height, ['bg'] = bg, ['color'] = color, ['border'] = border, ['text'] = text, ['action'] = action}
  drawRect(x, y, width, height, bg, border)
  drawText((x + width / 2) - (#text - colorsCount(text)) / 4, y + height / 2, color, text)
end

function drawMultiButton(x, y, width, height, buttons_list)
  if x == "center" then
    x = alignCenter(_, _, width, 1)[1]
  end
  if y == "center" then
    y = alignCenter(_, _, 1, height)[2]
  end
  for i = 1, #buttons_list do
    drawButton(x + width / #buttons_list * (i - 1), y, width / #buttons_list, height, buttons_list[i]['style'][1], buttons_list[i]['style'][2], buttons_list[i]['style'][3], buttons_list[i]['text'], buttons_list[i]['action'])
  end
end
function draw(data)
  if data then
    buttons = {}
    for key, value in pairs(data['windows']) do
      local head = value['head']
      if head['visible'] == true or head['visible'] == false then
        local window_w = calc(head['width'], w, h)
        local window_h = calc(head['height'], w, h)
        if window_w > head['max-width'] then window_w = head['max-width'] end
        local body = value['body']
        local type, style, width, height
        for i = 1, #body do
          type = body[i]['type']:lower()
          style = body[i]['style']
          if style[3] == "full" then width = style[3] elseif style[3] ~= "parent" then width = calc(style[3], window_w, h) else width = window_w end
          if style[4] then
            if style[4] == "full" then height = style[4] elseif style[4] ~= "parent" then height = calc(style[4], w, window_h) else height = window_h end
          end
          -- Прямоугольник
          if type == "rect" then
            drawRect(style[1], style[2], width, height, style[5], style[6])
          -- Кнопка
          elseif type == "button" then
            drawButton(style[1], style[2], width, height, style[5], style[6], style[7], body[i]['text'], body[i]['action'])
          elseif type == "multibutton" then
            drawMultiButton(style[1], style[2], width, height, body[i]['buttons'])
          -- Текст
          elseif type == "text" then
            drawText(style[1], style[2], style[3], body[i]['text'])
          -- Полоса разделения
          elseif type == "line" then
            drawLine(style[1], style[2], width, style[4])
          end
        end
      end
    end
  end
end

function click(button)
  local color = 0x2b2b2b
  drawButton(button['x'], button['y'], button['width'], button['height'], color, button['color'], button['border'], button['text'], button['action'])
  os.sleep(0.1)
  drawButton(button['x'], button['y'], button['width'], button['height'], button['bg'], button['color'], button['border'], button['text'], button['action'])
end

function updateRes(x, y)
  gpu.setResolution(x, y)
  w, h = gpu.getResolution()
end
