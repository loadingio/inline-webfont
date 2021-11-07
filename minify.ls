require! <[fs fs-extra path uglifycss @plotdb/opentype.js ttf2woff2 colors]>
KB = -> (Math.round(it / 1024) + "KB").padStart(4,' ')

minify = (file) ->
  opentype.load file .then (font) ->
    console.log "Processing #file ...".cyan
    glyphs = []
    for k,g of font.glyphs.glyphs =>
      glyphs.push g
      if !g.name => g.name = ''
    glyphs = glyphs.filter ->
      if /BenchNine/.exec(file) => return it.unicode > 42 and it.unicode < 58 or it == 0
      return (it.unicode > 31 and it.unicode < 128) or it == 0
    console.log "  reduce glyphs: #{font.glyphs.length} -> #{glyphs.length}"

    size = fs.stat-sync file .size
    nf = new opentype.Font({glyphs: glyphs} <<< {
      familyName: font.names.fontFamily.en, styleName: font.names.fontSubfamily.en
    } <<< font{unitsPerEm, ascender, descender})
    buf = (Buffer.from(nf.toArrayBuffer!))
    wbuf = ttf2woff2(buf)
    b64 = wbuf.toString \base64
    datauri = "data:font/woff2;base64,#b64"
    console.log(
      "  (#{KB size}) > reduced(#{KB buf.length}) > woff2(#{KB wbuf.length}) > inline(#{KB datauri.length})",
      "#{KB (size - datauri.length)} saved (#{Math.round(100 * (size - datauri.length) / size)}%)".yellow
    )
    console.log!
    [name, weight] = path.basename(file).replace(/\..*$/, '').split \-
    weight = {"Light": 300, "Regular": 400, "Medium": 500, "Bold": 700}[weight]
    css = """
    @font-face {
      font-family: '#name';
      font-style: normal;
      font-weight: #weight;
      font-display: optional;
      src: url('#datauri') format('woff2');
    }
    """
    return css

process-files = (files) ->
  Promise.all files.map(-> minify it)
    .then (css-list) ->
      css = css-list.join \\n
      css-min = uglifycss.process-string css
      fs-extra.ensure-dir-sync 'dist'
      fs.write-file-sync "dist/fonts.css", css
      fs.write-file-sync "dist/fonts.min.css", css-min
      console.log " >> output css file size: "
      console.log "    font.css:     #{(css.length / 1024).toFixed(2)}KB".green
      console.log "    font.min.css: #{(css-min.length / 1024).toFixed(2)}KB".green
      console.log!

process-files fs.readdir-sync('src').map(-> "src/#it")
  .then ->
    console.log \done.
    process.exit!
