require "sketchup.rb"

module VU1
  def self.export_entities(of, id, entities, o = nil, emat = nil)
    fname = @spath + "/ohisama/"
    entities.each { |ent|
      next if ent.hidden? or not ent.layer.visible?
      case ent.typename
      when "ComponentInstance"
        id = ent.entityID
        ema = ent.material if ent.material
        export_entities(of, id, ent.definition.entities , o * ent.transformation, ema)
      when "Group"
        id = ent.entityID
        ema = ent.material if ent.material
        export_entities(of, id, ent.entities , o * ent.transformation, ema)
        else
          #UI.messagebox ent.typename
      end
    }
    faces = entities.find_all { |e| e.typename == "Face"}
    faces.each { |f|
      @tw.load(f, true)
      @tw.load(f, false)
    }
    verts = faces.map { |f|
      f.vertices
    }
    if verts.length < 1
      return
    end
    of.print "s "
    of.puts "#{id}"
    verts.flatten!
    verts.uniq!
    verts.each do |v|
      pt = v.position
      pt.transform!(o) if o
      vf = format("%8.6f %8.6f %8.6f", pt.x.to_f / 100, pt.z.to_f / 100, -pt.y.to_f / 100)
      of.print "v #{vf}\n"
    end
    faces.each do |f|
      mata = nil
      matb = nil
      mata = f.material
      matb = f.back_material
      tex = nil
      tex = mata.texture if mata
      tex = matb.texture if matb
      if tex
        uh = f.get_UVHelper(true, false, @tw)
        f.outer_loop.vertices.each { |vertex|
          pos = vertex.position
          uv = uh.get_front_UVQ(pos).to_a if mata
          uv = uh.get_back_UVQ(pos).to_a if matb
          uvf = format("%8.6f %8.6f ", uv.x.to_f / tex.width , uv.y.to_f / tex.height) if mata
          uvf = format("%8.6f %8.6f ", uv.x.to_f / tex.width , uv.y.to_f / tex.height) if matb
          of.print "vt #{uvf}\n"
        }
      end
    end
    j = 0
    faces.each do |f|
      mat = nil
      mata = nil
      matb = nil
      mata = f.material
      matb = f.back_material
      tex = nil
      if mata
        mat = mata
        tex = mata.texture
      end
      if matb
        mat =matb
        tex = matb.texture
      end
      texFile = nil
      if tex
        texFile = tex.filename.to_s
        ri = texFile.rindex("\\")
        if ri
          texFile = texFile.slice!(ri + 1, texFile.length)
        end
      end
      if texFile
        @tw.write(f, true, fname + texFile) if mata
        @tw.write(f, false, fname + texFile) if matb
      end
      mname = "SkpColor"
      if mat != nil
        mname = mat.name.gsub(/マテリアル/,"material")
        mname = mname.gsub(/\W/,"")
        alpha = 1
        alpha = mat.alpha if mat.use_alpha?
        @materials[mname] = [mname, mat.color, texFile, alpha]
      else
        @materials[mname] = [mname, nil, nil, nil]
      end
      of.print "usemtl #{mname}\n"
      of.print "f "
      f.outer_loop.vertices.each do |v|
        i = verts.index(v) + @verts
        if texFile
          @uvcnt += 1
          of.print "#{i}/#{@uvcnt} "
        else
          of.print "#{i} "
        end
      end
      of.puts
      j += 1
      Sketchup.set_status_text("out face " + (faces.length - j).to_s)
    end
    of.puts
    @verts += verts.length
  end
  def self.out_materials(f)
    for n, mat in @materials
      if n == "SkpColor"
        text = "\nnewmtl SkpColor \nKa 1.0 1.0 1.0 \nKd 1.0 1.0 1.0 \nd 1.0 \nKs 0.0 0.0 0.0 \nNs 1.0"
      else
        name = mat[0]
        color = mat[1]
        textureFile = mat[2]
        alpha = mat[3]
        col = format("%8.4f %8.4f %8.4f", 1.0, 1.0, 1.0)
        if !textureFile
          col = format("%8.4f %8.4f %8.4f", color.red / 255.0, color.green / 255.0, color.blue / 255.0)
        end
        specular = format("%8.4f", 1.0)
        tex = ""
        tex = "map_Kd #{textureFile}" if textureFile
        text = "\nnewmtl #{name} \nKa 1.0 1.0 1.0 \nKd #{col} \nd #{alpha} \nKs 0.0 0.0 0.0 \nNs #{specular} \n#{tex} \n"
      end
      f.puts(text)
    end
  end
  def self.out_vdr(f)
    Sketchup.set_status_text("Start vidro  ")
    model = Sketchup.active_model
    sun = Sketchup.active_model.shadow_info["SunDirection"]
    sv = Geom::Vector3d.new (sun.x, sun.y, sun.z)
    sv = sv.normalize
    sx = sv.x
    sy = sv.z
    sz = -sv.y
    sf = format("%4.3f %4.3f %4.3f", sx.to_f, sy.to_f, sz.to_f)
    camera = model.active_view.camera
    eye = camera.eye
    ex = eye.x / 100
    ey = eye.z / 100
    ez = -eye.y / 100
    ef = format("%10.8f %10.8f %10.8f", ex.to_f, ey.to_f, ez.to_f)
    target = camera.target
    tx = target.x / 100
    ty = target.z / 100
    tz = -target.y / 100
    tf = format("%10.8f %10.8f %10.8f", tx.to_f, ty.to_f, tz.to_f)
    fl = camera.focal_length / 1000
    fs = 35 / camera.fov * 0.040
    for n, mat in @materials
      if n == "SkpColor"
        name = "SkpColor"
        color = Sketchup::Color.new (255, 255, 255)
        textureFile = ""
        alpha = 1.0
      else
        name = mat[0]
        color = mat[1]
        textureFile = mat[2]
        alpha = mat[3]
      end
      f.puts('new Material "' + name + '"')
      f.puts('  Normal ""')
      f.puts('  Volume 0 0')
      f.puts('  IOR 1 1')
      f.puts('  Transparency 0 0 0 ""')
      f.puts('  Jump "' + name + '" "' + name + '"')
      f.puts('  Emission 0 0 0 "" ""')
      f.puts('  HardLight 0')
      f.puts('  Reflection 0 0 0 ""')
      f.puts('  ReflectionIOR 1 1 1')
      f.puts('  Specular 0 0 0 ""')
      f.puts('  SpecularReflectance  0 0 0')
      f.puts('  Exponent 1 1')
      f.puts('  Axis 0 1 0')
      col = format("%8.4f %8.4f %8.4f", color.red / 255.0, color.green / 255.0, color.blue / 255.0)
      f.puts('  Diffuse  ' + col + ' "' + textureFile.to_s + '"' )
      f.puts('  LightingToneMin 0 0 0')
      f.puts('  LightingToneMax 2 2 2')
      f.puts('  LightingTone 0 1 1 1 "" 0.5 0.5 0.5 ""')
      f.puts('  LightingTone 1 1 1 1 "" 1.5 1.5 1.5 ""')
      f.puts('  ViewToneMin  0 0 0')
      f.puts('  ViewToneMax  1 1 1')
      f.puts('  ViewTone  0 0 0 0 "" 0 0 0 ""')
      f.puts('  ViewTone  1 0 0 0 "" 1 1 1 ""')
      f.puts('  ContourGroup 0')
      f.puts('  Background 0')
    end
    f.puts('new Space "0"')
    f.puts('new Volume "OUTER"')
    f.puts('  Environment    0.5 0.5 0.75 "sky.hdr"')
    f.puts('new ParallelLight')
    f.puts('  Emission    0.5 0.5 0.25')
    f.puts("  Direction    #{sf}")
    f.puts('new Eye')
    f.puts("  Position    #{ef} ")
    f.puts("  Focus       #{tf} ")
    f.puts("  FilmSize    #{fs.to_f}")
    f.puts("  FocalLength #{fl.to_f}")
    f.puts('new Volume "INNER"')
    f.puts('    HomogeneousExtinction    10.0 0.0 5.0')
    f.puts('new Object')
    f.puts('  File        "vtest1.obj"')
  end
  def self.obj_export
    @spath = File.dirname(__FILE__)
    #spath = Sketchup.find_support_file ("Plugins")
    fname = @spath + "/ohisama/vtest1.obj"
    @tw = Sketchup.create_texture_writer
    id = "model"
    of = File.new(fname, "w")
    of.puts "#Exported from Sketchup"
    of.puts "mtllib vtest1.mtl"
    @verts = 1
    @materials = {}
    @uvcnt = 0
    entities = Sketchup.active_model.entities
    #Sketchup.active_model.start_operation "ex...."
    o = Geom::Transformation.new
    export_entities(of, id, entities, o)
    of.flush
    of.close
    fm = File.new (fname.gsub(".obj", ".mtl"), "w")
    fm.puts "#Exported from Sketchup"
    out_materials(fm)
    fm.close;
    fv = File.new (fname.gsub(".obj", ".vdr"), "w")
    fv.puts "vidro090517"
    fv.puts "#Exported from Sketchup"
    out_vdr(fv)
    fv.close;
    UI.openURL(@spath + "/ohisama/run1.bat")
  end
end
if (not file_loaded?("viup1.rb"))
  begin
    Ohi_menu.add_item("viup1") {VU1::obj_export}
  rescue
    Ohi_menu = UI.menu("Plugins").add_submenu("Ohisama")
    Ohi_menu.add_item("viup1") {VU1::obj_export}
  end
end
file_loaded("viup1.rb")
