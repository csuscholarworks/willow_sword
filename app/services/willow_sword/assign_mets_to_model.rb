module WillowSword
  module AssignMetsToModel

    def assign_mets_to_model
      # descriptive metadata
      assign_model
      assign_access_condition
      assign_abstract
      assign_dataset
      assign_genre
      assign_identifiers
      assign_in_progress
      assign_language
      assign_name
      assign_note
      assign_origin_info
      assign_patent
      assign_physical_description
      assign_related_item
      assign_subject
      assign_thesis
      assign_title
      # Admin metadata
      assign_deposit_license
      assign_record_info
      assign_ora_admin
      assign_ref_admin
      assign_thesis_admin
      assign_embargo_info
    end

    def assign_files_metadata
      # contains a hash with the keys fileid, dmdid, filepath, metadata
      @files_metadata.each do |file|
        file_md = file.fetch('metadata', {})
        next unless file_md.any?
        @files_metadata['mapped_metadata'] = assign_file_metadata(file_md)
      end
    end

    private

    # =================================
    # descriptive metadata
    # =================================

    def assign_abstract
      # abstract
      if @metadata.fetch('abstract', []).any?
        @mapped_metadata['abstract'] = Array(@metadata['abstract']).first
      end
      # abstract - summary_documentation
      vals = Array(@metadata.fetch('summary_documentation', []))
      if vals.any?
        parent = 'bibliographic_information'
        bib_attr = { 'summary_documentation' => vals[0] }
        assign_nested_hash(parent, bib_attr)
      end
    end

    def assign_access_condition
      # access_condition
      return unless @metadata.fetch('access_condition', []).any?
      li_fields = %w(license license_statement license_start_date license_url rights_statement)
      li_attrs = {}
      admin_attrs = {}
      @metadata['access_condition'].each do |key, vals|
        if li_fields.include?(key)
          li_attrs[key] = Array(vals)[0] if Array(vals).any?
        elsif key == 'record_ora_deposit_licence'
          admin_attrs[key] = Array(vals)[0] if Array(vals).any?
        end
      end
      assign_nested_hash('licence_and_rights_information', li_attrs) if li_attrs.any?
      assign_nested_hash('admin_information', admin_attrs) if admin_attrs.any?
    end

    def assign_dataset
      dataset = {}
      fields = {
        'data_collection_start' => 'data_collection_start_date',
        'data_collection_end' => 'data_collection_end_date',
        'dataset_spatial' => 'data_coverage_spatial',
        'data_coverage_start' => 'data_coverage_temporal_start_date',
        'data_coverage_end' => 'data_coverage_temporal_end_date',
        'dataset_type' => 'data_format',
        'digital_storage_location' => 'data_digital_storage_location',
        'dataset_extent' => 'data_digital_data_total_file_size',
        'dataset_format' => 'data_digital_data_format',
        'dataset_version' => 'data_digital_data_version',
        'physical_storage_location' => 'data_physical_storage_location',
        'dataset_references' => 'data_management_plan_url'
      }
      fields.each do |data_fld, model_fld|
        vals = Array(@metadata.fetch(data_fld, []))
        dataset[model_fld] = vals[0] if vals.any?
      end
      parent = 'bibliographic_information'
      assign_nested_hash(parent, dataset) if dataset.any?
    end

    def assign_genre
      genre_fields = %w(sub_type_of_work type_of_work)
      parent = 'item_description_and_embargo_information'
      desc_attrs = {}
      genre_fields.each do |field|
        vals = Array(@metadata.fetch(field, []))
        desc_attrs[field] = vals[0] if vals.any?
      end
      assign_nested_hash(parent, desc_attrs) if desc_attrs.any?
    end

    def assign_identifiers
      ids = @metadata.fetch('identifiers', [])
      return unless ids.any?

      # map attribute names to model fields
      pub_keys = {
        'doi' => 'identifier_doi',
        'eisbn' => 'identifier_eisbn',
        'eissn' => 'identifier_eissn',
        'isbn' => 'identifier_isbn_10',
        'isbn13' => 'identifier_isbn_13',
        'issn' => 'identifier_issn',

      }
      item_desc_keys = {
        # item_description_and_embargo_information
        'pii' => 'pii',
        'pmid' => 'identifier_pmid',
        'pubs_id' => 'identifier_pubs_identifier',
        'tinypid' => 'tinypid',
        'uuid' => 'identifier_uuid'

      }
      admin_keys = {
        'source_identifier' => 'identifier_source_identifier',
        'tombstone' => 'identifier_tombstone_record_identifier'
      }
      bib_keys = {
        'paper_number' => 'paper_number'
      }

      # Extract the identifier values for each identifier
      pub_attrs = {}
      item_desc_attrs = {}
      admin_attrs = {}
      bib_attrs = {}
      record_attrs = []
      ids.each do |key,vals|
        next unless Array(vals).any?
        if pub_keys.include?(key)
          pub_attrs[pub_keys[key]] = Array(vals).first
        elsif item_desc_keys.include?(key)
          item_desc_attrs[item_desc_keys[key]] = Array(vals).first
        elsif admin_keys.include?(key)
          admin_attrs[admin_keys[key]] = Array(vals).first
        elsif bib_keys.include?(key)
          bib_attrs[bib_keys[key]] = Array(vals).first
        else
          attrs = {
            'record_identifier_scheme' => key,
            'record_identifier' => Array(vals).first
          }
          record_attrs << attrs
        end
      end
      item_desc_attrs['record_identifiers_attributes'] = record_attrs if record_attrs.any?

      # Assign the identifiers
      # bibliographic_information identifiers
      parent = 'bibliographic_information'
      assign_nested_hash(parent, bib_attrs)
      # bibliographic_information - publisher identifiers
      child = 'publishers'
      assign_second_nested_hash(parent, child, pub_attrs)
      # item_description_and_embargo_information identifiers
      parent = 'item_description_and_embargo_information'
      assign_nested_hash(parent, item_desc_attrs)
      # admin_information identifiers
      parent = 'admin_information'
      assign_nested_hash(parent, admin_attrs)
    end

    def assign_in_progress
      # Add in-progress header
      return unless @metadata.dig('headers', 'in_progress').blank?
      admin_attrs = {}
      vals = Array(@metadata['headers'].fetch('in_progress', []))
      admin_attrs['deposit_in_progress'] = vals[0] if vals.any?
      assign_nested_hash('admin_information', admin_attrs)
    end

    def assign_language
      # Language
      if @metadata.fetch('language', []).any?
        @mapped_metadata['language'] = Array(@metadata['language'])
      end
    end

    def assign_location
      # TODO: location - physical_location
      #   No equivalent Hyrax field found
      # location - url
      vals = Array(@metadata.fetch('url',[]))
      if vals.any?
        parent = 'admin_information'
        admin_attrs = { 'has_public_url' => vals[0] }
        assign_nested_hash(parent, admin_attrs)
      end
    end

    def assign_name
      @metadata.fetch('names', []).each do |nam|
        typ = nam.fetch('type', nil)
        roles = nam.fetch('roles', []).map { |r| r['role_term'] }
        if typ == 'corporate' and roles.include?('Commissioning body')
          assign_name_commissioning_body(nam)
        elsif typ == 'corporate' and roles.include?('Copyright holder')
          assign_name_rights_holder(nam)
        elsif typ == 'corporate' and roles.include?('Funder')
          assign_name_funder(nam)
        elsif typ == 'corporate' and roles.include?('Publisher')
          assign_name_publisher(nam)
        else
          assign_name_person(nam)
        end
      end
    end

    def assign_name_commissioning_body(nam)
      vals = Array(nam.fetch('display_form', []))
      if vals.any?
        parent = 'bibliographic_information'
        bib_attr = { 'commissioning_body' => vals[0] }
        assign_nested_hash(parent, bib_attr)
      end
    end

    def assign_name_rights_holder(nam)
      vals = Array(nam.fetch('display_form', []))
      if vals.any?
        parent = 'license_and_rights_information'
        rights_attr = { 'rights_holders' => vals[0] }
        assign_nested_hash(parent, rights_attr)
      end
    end

    def assign_name_person(nam)
      # NOT in model
      #   preferred_initials
      name_fields = {
        'family' => 'family_name',
        'given' => 'given_names',
        'initials' => 'initials',
        'display_form' => 'display_name',
        'preferred_family' => 'preferred_family_name',
        'preferred_given' => 'preferred_given_name',
        'preferred_email' => 'preferred_contributor_email',
        'type' => 'contributor_type',
      }
      affiliation_fields = {
        'division' => 'division',
        'department' => 'department',
        'sub_department' => 'sub_department',
        'research_group' => 'research_group',
        'oxford_college' => 'oxford_college',
        'sub_unit' => 'sub_unit'
      }
      id_fields = {
        'email_address' => 'contributor_email',
        'website' => 'contributor_website_url',
        'contributor_record_identifier' => 'contributor_record_identifier',
        'sso' => 'contributor_institutional_identifier',
        'orcid_identifier' => 'orcid_identifier'
      }
      mapped_name = {}
      nam.each do |key, val|
        if name_fields.include?(key)
          mapped_name[name_fields[key]] = Array(val).first if Array(val).any?
        elsif key == 'affiliation'
          val.each do |aff_key, aff_val|
            if affiliation_fields.include?(aff_key)
              mapped_name[affiliation_fields[aff_key]] = Array(aff_val).first if Array(aff_val).any?
            end
          end
        elsif key == 'institution'
          val.each do |inst_val|
            vals = Array(inst_val.fetch('institution', []))
            mapped_name['institution'] = vals.first if vals.any?
            vals = Array(inst_val.fetch('identifier', []))
            mapped_name['institution_identifier'] = vals.first if vals.any?
          end
        elsif key == 'identifier'
          other_ids = []
          val.each do |id_key, id_val|
            if id_fields.include?(id_key)
              mapped_name[id_fields[id_key]] = Array(id_val).first if Array(id_val).any?
            elsif Array(id_val).any?
              id = {}
              id['contributor_identifier_scheme'] = id_key
              id['contributor_identifier'] = Array(id_val).first
              other_ids << id
            end
          end
          mapped_name['contributor_identifier_attributes'] = other_ids if other_ids.any?
        elsif key == 'roles'
          # Ensuring all values are singular
          roles = []
          val.each do |role_val|
            role = {}
            vals = Array(role_val.fetch('role_title', []))
            if vals.any?
              role['role_title'] = vals.first
              role['et_al'] = @metadata.fetch('et_al_roles', []).include? vals.first
            end
            vals = Array(role_val.fetch('role_order', []))
            role['role_order'] = vals.first if vals.any?
            roles << role if role.any?
          end
          mapped_name['roles_attributes'] = roles if roles.any?
        end
        assign_nested_hash('creators_and_contributors', mapped_name, false)
      end
    end

    def assign_name_funder(nam)
      funder = {}
      funder_fields = {
        'display_form' => 'funder_name',
        'identifier' => 'funder_identifier',
        'funding_programme' => 'funder_funding_programme',
        'funder_compliance' => 'funder_compliance_met'
      }
      funder_fields.each do |data_field, model_field|
        vals = Array(nam.fetch(data_field, []))
        funder[model_field] = vals.first if vals.any?
      end
      grants = []
      grant_fields = %w(grant_identifier is_funding_for)
      nam.fetch('grants', []).each do |grant|
        mapped_grant = {}
        grant_fields.each do |field|
          vals = Array(grant.fetch(field, []))
          mapped_grant[field] = vals.first if vals.any?
        end
        grants << mapped_grant if mapped_grant.any?
      end
      funder['funder_grant_attributes'] = grants if grants.any?
      assign_nested_hash('funders', funder, false)
    end

    def assign_name_publisher(nam)
      pub_attrs = {}
      vals = Array(nam.fetch('display_form', []))
      pub_attrs['publisher_name'] = vals[0] if vals.any?
      urls = []
      nam.fetch('identifier', []).each do |k, v|
        urls << Array(v).first if k == 'website' && Array(v).any?
      end
      pub_attrs['publisher_website_url'] = urls[0] if urls.any?
      parent = 'bibliographic_information'
      child = 'publishers'
      assign_second_nested_hash(parent, child, pub_attrs) if pub_attrs.any?
    end

    def assign_note
      # note - additional_information
      vals = Array(@metadata.fetch('additional_information', []))
      @mapped_metadata['additional_information'] = vals.first if vals.any?
    end

    def assign_patent
      bib_attrs = {}
      fields = %w(patent_number patent_application_number patent_publication_number
                  patent_awarded_date patent_filed_date patent_status patent_territory
                  patent_cooperative_classification patent_european_classification
                  patent_international_classification)
      # patent_number
      fields.each do |field|
        vals = Array(@metadata.fetch(field, []))
        bib_attrs[field] = vals.first if vals.any?
      end
      parent = 'bibliographic_information'
      assign_nested_hash(parent, bib_attrs) if bib_attrs.any?
    end

    def assign_origin_info
      # publisher information
      pub_attrs = {}
      fields = {
        'date_of_acceptance' => 'acceptance_date',
        'date_issued' => 'citation_publication_date',
        'publication_place' => 'citation_place_of_publication',
        'publication_url' => 'publication_url'
      }
      fields.each do |data_field, model_field|
        vals = Array(@metadata.fetch(data_field, []))
        pub_attrs[model_field] = vals.first if vals.any?
      end
      parent = 'bibliographic_information'
      child = 'publishers'
      assign_second_nested_hash(parent, child, pub_attrs) if pub_attrs.any?
      # license_and_rights_information
      rights_attrs = {}
      vals = Array(@metadata.fetch('copyright_date', []))
      rights_attrs['rights_copyright_date'] = vals[0] if vals.any?
      parent = 'license_and_rights_information'
      assign_nested_hash(parent, rights_attrs)
    end

    def assign_physical_description
      return unless @metadata.fetch('form', {}).any?
      # physicalDescription - form
      fields = %w(physical_form physical_dimensions)
      form = {}
      fields.each do |field|
        vals = @metadata['form'].fetch(field, [])
        form[field] = vals.first if vals.any?
      end
      parent = 'bibliographic_information'
      assign_nested_hash(parent, form) if form.any?
    end

    def assign_related_item        # related item
      @metadata.fetch('related_items', []).each do |ri|
        typ = ri.fetch('type', nil)
        other_type = ri.fetch('other_type', nil)
        if other_type == 'event'
          assign_ri_event(ri)
        elsif other_type == 'related_item'
          assign_ri_ri(ri)
        elsif typ == 'host'
          assign_ri_host(ri)
          assign_ri_host_dataset(ri) if @model == 'dataset'
          assign_ri_host_artile(ri) if @model == 'article'
        elsif typ == 'series'
          assign_ri_series
        end
      end
    end

    def assign_ri_event(ri)
      event = {}
      fields = {
        'related_item_title' => 'event_title',
        'related_item_physical_location' => 'event_location',
        'related_item_url' => 'event_website_url',
        'related_item_event_start_date' => 'event_start_date',
        'related_item_event_end_date' => 'event_end_date'
      }
      fields.each do |data_fld, model_fld|
        vals = Array(ri.fetch(data_fld, []))
        event[model_fld] = vals[0] if vals.any?
      end
      parent = 'bibliographic_information'
      child = 'event'
      assign_second_nested_hash(parent, child, event, false)
    end

    def assign_ri_ri(ri_hash)
      ri = {}
      fields = {
        'related_item_title' => 'related_item_title',
        'related_item_url' => 'related_item_identifier',
        'related_item_citation_text' => 'related_item_citation_text'
      }
      fields.each do |data_fld, model_fld|
        vals = Array(ri_hash.fetch(data_fld, []))
        ri[model_fld] = vals[0] if vals.any?
      end
      assign_nested_hash('related_items', ri, false)
    end

    def assign_ri_host_dataset(ri)
      host = {}
      fields = {
        'related_item_title' => 'host_title',
        'related_item_subtitle' => 'journal_title'
      }
      fields.each do |data_fld, model_fld|
        vals = Array(ri.fetch(data_fld, []))
        host[model_fld] = vals[0] if vals.any?
      end
      parent = 'bibliographic_information'
      child = 'publishers'
      assign_second_nested_hash(parent, child, host) if host.any?
    end

    def assign_ri_host_article(ri)
      host = {}
      fields = {
        'related_item_title' => 'journal_title',
        'related_item_article_number' => 'article_number',
        'related_item_url' => 'journal_website_url'
      }
      fields.each do |data_fld, model_fld|
        vals = Array(ri.fetch(data_fld, []))
        host[model_fld] = vals[0] if vals.any?
      end
      parent = 'bibliographic_information'
      child = 'publishers'
      assign_second_nested_hash(parent, child, host) if host.any?
    end

    def assign_ri_host(ri)
      host = {}
      fields = {
        'related_item_chapter_number' => 'chapter_number',
        'related_item_edition' => 'edition',
        'related_item_issue' => 'issue_number',
        'related_item_pages' => 'pagination',
        'related_item_series_number' => 'series_number',
        'related_item_volume' => 'volume'
      }
      fields.each do |data_fld, model_fld|
        vals = Array(ri.fetch(data_fld, []))
        host[model_fld] = vals[0] if vals.any?
      end
      parent = 'bibliographic_information'
      child = 'publishers'
      assign_second_nested_hash(parent, child, host) if host.any?

      fields = {
        'related_item_status' => 'host_publication_status',
        'related_item_peer_reviewed' => 'host_peer_review_status'
      }
      fields.each do |data_fld, model_fld|
        vals = Array(ri.fetch(data_fld, []))
        @mapped_metadata[model_fld] = vals[0] if vals.any?
      end
    end

    def assign_ri_series(ri)
      series = {}
      fields = {
        'related_item_title' => 'series_title',
        'related_item_series_number' => 'series_number'
      }
      fields.each do |data_fld, model_fld|
        vals = Array(ri.fetch(data_fld, []))
        series[model_fld] = vals[0] if vals.any?
      end
      parent = 'bibliographic_information'
      child = 'publishers'
      assign_second_nested_hash(parent, child, series) if series.any?
    end

    def assign_subject
      fields = {
        'genre' => 'keyword',
        'topic' => 'subject'
      }
      fields.each do |data_fld, model_fld|
        vals = Array(@metadata.fetch(data_fld, []))
        # Subject and keyword are multi-valued
        @mapped_metadata[model_fld] = vals if vals.any?
      end
    end

    def assign_thesis
      fields = %w(thesis_degree_institution thesis_degree_level
                  thesis_degree_name thesis_leave_to_supplicate_date)
      thesis = {}
      fields.each do |field|
        vals = @metadata.fetch(field, [])
        thesis[field] = vals.first if vals.any?
      end
      parent = 'bibliographic_information'
      assign_nested_hash(parent, thesis) if thesis.any?
    end

    def assign_title
      # title
      vals = Array(@metadata.fetch('title', []))
      @mapped_metadata['title'] = vals.first if vals.any?
      # subtitle
      vals = Array(@metadata.fetch('subtitle', []))
      @mapped_metadata['alternative_title'] = vals.first if vals.any?
    end

    # =================================
    # administritive metadata
    # =================================

    def assign_deposit_license
      vals = Array(@metadata.fetch('record_ora_deposit_licence', []))
      return unless vals.any?
      admin_attrs = { 'record_ora_deposit_licence' => vals[0] }
      assign_nested_hash('admin_information', admin_attrs)
    end

    def assign_record_info
      admin_attrs = {}
      bib_attrs = {}
      license_attrs = {}

      # recordCreationDate
      vals = Array(@metadata.fetch('recordCreationDate', []))
      admin_attrs['record_creation_date'] = vals[0] if vals.any?

      # recordContentSource
      vals = Array(@metadata.fetch('recordContentSource', []))
      admin_attrs['record_content_source'] = vals[0] if vals.any?

      # recordInfoNote
      info_note_fields = {
        'accept_updates' => 'record_accept_updates',
        'admin_notes' => 'admin_notes',
        'confidential_report' => 'confidential_report',
        'deposit_note' => 'deposit_note',
        'ora_data_model_version' => 'ora_data_model_version',
        'pre_counter_downloads' => 'pre_counter_downloads',
        'pre_counter_views' => 'pre_counter_views',
        'requires_review' => 'record_requires_review',
      }
      admin_fields = %w(record_accept_updates admin_notes
                        ora_data_model_version record_requires_review)
      bib_fields = %w(confidential_report)
      license_fields = %w(deposit_note)
      if @metadata.fetch('recordInfoNote', {}).any?
        info_note_fields.each do |data_fld, model_fld|
          vals = Array(@metadata['recordInfoNote'].fetch(data_fld, []))
          if admin_fields.include? model_fld
            admin_attrs[model_fld] = vals[0] if vals.any?
          elsif bib_fields.include? model_fld
            bib_attrs[model_fld] = vals[0] if vals.any?
          elsif license_fields.include? model_fld
            license_attrs[model_fld] = vals[0] if vals.any?
          end
        end
      end
      assign_nested_hash('admin_information', admin_attrs) if admin_attrs.any?
      assign_nested_hash('bibliographic_information', bib_attrs) if bib_attrs.any?
      assign_nested_hash('license_and_rights_information', license_attrs) if license_attrs.any?
    end

    def assign_ora_admin
      pub_fields = %w(doi_requested)
      admin_fields = %w(depositor_contacted depositor_contact_email_template
      record_first_reviewed_by incorrect_version_deposited record_deposit_date
      record_publication_date record_review_status record_review_status_other
      record_version rt_ticket_number)
      rights_fields = %w(rights_third_party_copyright_material
                        rights_third_party_copyright_permission_received)
      action_fields = {
        'note' => 'action_comment',
        'date' => 'action_date',
        'description' => 'action_description',
        'temporal' =>'action_duration',
        'contributor' => 'action_responsibility'
      }
      return unless @metadata.fetch('admin_info', {}).any?
      # Assign publisher attributes
      pub_attrs = {}
      pub_fields.each do |field|
        vals = Array(@metadata['admin_info'].fetch(field, []))
        pub_attrs[field] = vals[0] if vals.any?
      end
      parent = 'bibliographic_information'
      child = 'publishers'
      assign_second_nested_hash(parent, child, pub_attrs)
      # Assign admin attributes
      admin_attrs = {}
      admin_fields.each do |field|
        vals = Array(@metadata['admin_info'].fetch(field, []))
        admin_attrs[field] = vals[0] if vals.any?
      end
      # assign history action wthin admin
      history = []
      history_actions = Array(@metadata['admin_info'].fetch('history_actions', []))
      history_actions.each do |action|
        history_action = {}
        action_fields.each do |data_field, model_field|
          vals = Array(action.fetch(data_field, []))
          history_action[model_field] = vals[0] if vals.any?
        end
        history << history_action if history_action.any?
      end
      admin_attrs['history_attributes'] = history if history.any?
      assign_nested_hash('admin_information', admin_attrs) if admin_attrs.any?
      # Assign rights attributes
      rights_attrs = {}
      rights_fields.each do |field|
        vals = Array(@metadata['admin_info'].fetch(field, []))
        rights_attrs[field] = vals[0] if vals.any?
      end
      parent = 'licence_and_rights_information'
      assign_nested_hash(parent, rights_attrs) if rights_attrs.any?
    end

    def assign_ref_admin
      fields = {
        'apc_admin_apc_number' => 'apc_admin_apc_number',
        'apc_admin_review_status' => 'apc_admin_apc_review_status',
        'apc_admin_spreadsheet_identifier' => 'apc_admin_apc_spreadsheet_identifier',
        'ref_compliant_at_deposit' => 'ref_compliant_at_deposit',
        'ref_compliant_availability' => 'ref_compliant_availability',
        'ref_exception_required' => 'ref_exception_required',
        'ref_exception_note' => 'ref_other_exception_note',
      }
      admin_attrs = {}
      @metadata.fetch('ref_admin', {}).each do |key, val|
        next unless fields.include?(key)
        admin_attrs[fields[key]] = Array(val)[0] if Array(val).any?
      end
      assign_nested_hash('admin_information', admin_attrs) if admin_attrs.any?
    end

    def assign_thesis_admin
      fields = {
        'thesis_archive_version_completed' => 'thesis_archive_version_complete',
        'thesis_student_system_updated' => 'thesis_student_system_updated',
        'thesis_dispensation_from_consultation_granted' => 'thesis_dispensation_from_consultation_granted',
        'thesis_voluntary_deposit' => 'thesis_voluntary_deposit'
      }
      admin_attrs = {}
      @metadata.fetch('thesis_admin', {}).each do |key, val|
        next unless fields.include?(key)
        admin_attrs[fields[key]] = Array(val)[0] if Array(val).any?
      end
      assign_nested_hash('admin_information', admin_attrs) if admin_attrs.any?
    end

    def assign_embargo_info
      fields = %w(record_embargo_end_date record_embargo_reason record_embargo_release_method)
      desc_attrs = {}
      @metadata.fetch('thesis_admin', {}).each do |key, val|
        next unless fields.include?(key)
        desc_attrs[key] = Array(val)[0] if Array(val).any?
      end
      parent = 'item_description_and_embargo_information'
      assign_nested_hash(parent, desc_attrs) if desc_attrs.any?
    end

    def assign_file_metadata(file_metadata)
      mapped_file_metadata = {}
      fields = {
        'title' => 'file_name',
        'format' => 'file_format',
        'extent' => 'file_size',
        'hasVersion' => 'file_version',
        'location' => 'file_path',
        'datastream' => 'file_admin_fedora3_datastream_identifier',
        'version' => 'file_rioxx_version',
        'embargoedUntil' => 'file_embargo_end_date',
        'embargoComment' => 'file_embargo_comment',
        'embargoReleaseMethod' => 'file_embargo_release_method',
        'reasonForEmbargo' => 'file_embargo_reason',
        'lastAccessRequestDate' => 'file_last_access_request_date',
        'fileOrder' => 'file_order',
        'accessConditionAtDeposit' => 'access_condition_at_deposit',
        'fileAndRecordDoNotMatch' => 'file_admin_file_and_record_do_not_match',
        'hasPublicUrl' => 'file_public_url',
      }
      fields.each do |data_fld, model_fld|
        vals = Array(file_metadata.fetch(data,fld, []))
        mapped_file_metadata[model_fld] = vals[0] if vals.any?
      end
      mapped_file_metadata
    end

    # =================================
    # helpful methods
    # =================================
    def assign_nested_hash(parent, values, merge=true)
      @mapped_metadata["#{parent}_attributes"] ||= []
      if merge
        vals = @mapped_metadata["#{parent}_attributes"].first
        vals ||= {}
        vals.merge!(values)
        @mapped_metadata["#{parent}_attributes"] = [vals]
      else
        @mapped_metadata["#{parent}_attributes"] << values
      end
    end

    def assign_second_nested_hash(parent, child, values, merge=true)
      @mapped_metadata["#{parent}_attributes"] ||= []
      parent_vals = @mapped_metadata["#{parent}_attributes"].first
      parent_vals ||= {}
      parent_vals["#{child}_attributes"] ||= []
      if merge
        child_vals = parent_vals["#{child}_attributes"].first
        child_vals ||= {}
        child_vals.merge!(values)
        parent_vals["#{child}_attributes"] = [child_vals]
      else
        parent_vals["#{child}_attributes"] << values
      end
      @mapped_metadata["#{parent}_attributes"] = [parent_vals]
    end

  end
end