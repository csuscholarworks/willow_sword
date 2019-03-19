module WillowSword
  class CrosswalkToMets < CrosswalkToXml
    attr_reader :work, :doc

    def initialize(work)
      @work = work
      @doc = nil
    end

    def to_xml
      mets_root
      mods_xw = WillowSword::CrosswalkToMods.new(@work)
      mods_xw.to_xml
      add_dmdsec(mods_xw.doc)
      add_amdsec(mods_xw.rights, mods_xw.admin_doc)
      add_files
    end

    def mets_root
      cdate = Time.now.strftime('%Y-%m-%dT%H:%M:%S')
      mets = "<mets:mets
        xmlns:mets='http://www.loc.gov/METS/'
        xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'
        xsi:schemaLocation='http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd'>
          <mets:metsHdr CREATEDATE='#{cdate}'>
              <mets:agent OTHERTYPE='SOFTWARE' ROLE='CREATOR' TYPE='OTHER'>
                  <mets:name>Hyrax Sword</mets:name>
                  <mets:note/>
              </mets:agent>
          </mets:metsHdr>
        </mets:mets>"
      @doc = LibXML::XML::Document.string(mets)
    end

    def add_dmdsec(mods_xml)
      dmdsec = create_node('mets:dmdSec', nil, {'ID' => 'DMDLOG_0000'})
      md_wrap = create_node('mets:mdWrap', nil, {'MDTYPE' => 'MODS'})
      xml_data = create_node('mets:xmlData')
      @doc.root << dmdsec
      dmdsec << md_wrap
      md_wrap << xml_data
      unless mods_xml.blank?
        node = @doc.import(mods_xml.root)
        xml_data << node
      end
    end

    def add_amdsec(rights, mods_xml)
      amdsec = create_node('mets:amdSec', nil, {'ID' => 'AMDLOG_0000'})
      @doc.root << amdsec
      # rights
      rights_md = create_node('mets:rightsMD', nil, {'ID' => 'RIGHTSMD_01'})
      amdsec << rights_md
      md_wrap1 = create_node('mets:mdWrap', nil, {'MDTYPE' => 'METSRIGHTS'})
      rights_md << md_wrap1 
      xml_data1 = create_node('mets:xmlData')
      md_wrap1 << xml_data1
      rights_dec = create_node('metsrights:RightsDeclarationMD', nil, {
        'RIGHTSCATEGORY' => 'LICENSED'
      })
      add_namespaces(rights_dec, {'metsrights' => 'http://cosimo.stanford.edu/sdr/metsrights/'})
      xml_data1 << rights_dec
      rights_dec << create_node('metsrights:RightsDeclaration', rights)
      # source
      src_md = create_node('mets:sourceMD', nil, {'ID' => 'SOURCEMD_01'})
      amdsec << src_md
      md_wrap = create_node('mets:mdWrap', nil, {'MDTYPE' => 'MODS'})
      src_md << md_wrap
      xml_data = create_node('mets:xmlData')
      md_wrap << xml_data
      unless mods_xml.blank?
        node = @doc.import(mods_xml.root)
        xml_data << node
      end
    end

    def add_files
      # file sections
      file_sec = create_node('mets:fileSec')
      file_grp = create_node('mets:fileGrp')
      # struct map
      map = create_node('mets:structMap')
      add_attributes(map, {'TYPE' => 'LOGICAL'})
      div1 = create_node('mets:div')
      add_attributes(div1, {
        'DMDID' => 'DMDLOG_0000',
        'ADMID' => 'AMDLOG_0000',
        'ID' => 'LOG_0000',
        'LABEL' => 'Object ID',
        'TYPE' => 'Repository object'
      })
      # file dmdsec, file group and div for each file
      count = 0
      @work.file_sets.each do |file_set|
        count += 1
        mimetype = file_set.file_format
        filepath = file_set.file_public_url
        # Add file dmdsec
        xw = WillowSword::CrosswalkToOra.new(file_set)
        xw.to_xml
        add_file_dmdsec(count, xw.doc) unless xw.doc.blank?
        # Add file group
        file_grp << add_file_group(count, filepath, mimetype)
        # struct div2
        div1 << add_file_struct_div(count)
      end
      # complete file sections
      file_sec << file_grp
      @doc.root << file_sec
      # complete struct map
      map << div1
      @doc.root << map
    end

    def add_file_dmdsec(id, file_metadata)
      node1 = create_node('mets:dmdSec', nil, {'ID'=>file_dmdid(id)})
      node2 = create_node('mets:mdWrap', nil, {'MDTYPE'=>'OTHER'})
      node3 = create_node('mets:xmlData')
      @doc.root << node1
      node1 << node2
      node2 << node3
      node = @doc.import(file_metadata.root)
      node3 << node
    end

    def add_file_group(id, filepath, mimetype)
      unless filepath.blank?
        filepath = "file:///#{filepath}" unless filepath.starts_with?('http')
      end
      attributes = {}
      attributes['ID'] = file_id(id) unless id.blank?
      attributes['MIMETYPE'] = mimetype unless mimetype.blank?
      file_node = create_node('mets:file', nil, attributes)
      attributes = {'LOCTYPE' => 'URL'}
      attributes['xlink:href'] = filepath unless filepath.blank?
      file_loc = create_node('mets:FLocat', nil, attributes)
      add_namespaces(file_loc, {'xlink' => 'http://www.w3.org/1999/xlink'})
      file_node << file_loc
      file_node
    end

    def add_file_struct_div(id)
      div = create_node('mets:div', nil, {
        'DMDID' => file_dmdid(id),
        'LABEL' => file_id(id),
        'TYPE' => 'Repository file'
      })
      div << create_node('mets:fptr', nil, {'FILEID' => file_id(id)})
      div
    end

    def file_dmdid(id)
      "DMDFILE#{id.to_s.rjust(3, '0')}"
    end

    def file_id(id)
      "FILENAME#{id}"
    end

  end
end
