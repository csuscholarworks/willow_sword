module Integrator
  module Hyrax
    module FileSetsBehavior
      extend ActiveSupport::Concern

      def find_file_set
        return find_file_set_by_id if params[:id]
      end

      def create_file_set
        @file_set = @file_set_klass.create
        @current_user = User.batch_user unless @current_user.present?
        @actor = file_set_actor.new(@file_set, @current_user)
        @actor.file_set.permissions_attributes = @object.permissions.map(&:to_hash)
        # Add file
        unless @files.blank?
          chosen_file = @files.first
          f = upload_file(chosen_file)
          @actor.create_content(f)
          @actor.file_set.title = [File.basename(chosen_file)]
        end
        # update_metadata
        @actor.file_set.update(create_file_set_attributes) unless @attributes.blank?
        @actor.file_set.save!
        @actor.attach_to_work(@object) if @object
        set_in_progress_status_for_parent_work
      end

      def update_file_set
        raise "File set doesn't exist" unless @file_set
        @current_user = User.batch_user unless @current_user.present?
        @actor = file_set_actor.new(@file_set, @current_user)
        @actor.file_set.permissions_attributes = @object.permissions.map(&:to_hash)
        # update file
        unless @files.blank?
          chosen_file = @files.first
          f = upload_file(chosen_file)
          @actor.update_content(f)
          @actor.file_set.title = [File.basename(chosen_file)]
        end
        # update_metadata
        @actor.file_set.update(update_file_set_attributes) unless @attributes.blank?
        @actor.file_set.save!
        set_in_progress_status_for_parent_work
      end

      private
        def set_in_progress_status_for_parent_work
          # If a deposit is in progress, or has been completed, set the relevant
          # in progress and requires review flags
          # Add in-progress header
          return if @headers[:in_progress].blank?
          status = @headers[:in_progress]
          if status.downcase == 'true'
            @object.admin_information.first['deposit_in_progress'] = true
            @object.save
          elsif status.downcase == 'false'
            @object.admin_information.first['deposit_in_progress'] = false
            @object.admin_information.first['requires_review'] = true
            @object.save
          end
        end


        def find_file_set_by_id
          @file_set_klass.find(params[:id]) if @file_set_klass.exists?(params[:id])
        rescue ActiveFedora::ActiveFedoraError
          nil
        end

        def create_file_set_attributes
          transform_file_set_attributes.except(:id, 'id')
        end

        def update_file_set_attributes
          transform_file_set_attributes.except(:id, 'id')
        end

        def set_file_set_klass
          @file_set_klass = WillowSword.config.file_set_models.first.constantize
        end

        def transform_file_set_attributes
          if WillowSword.config.allow_only_permitted_attributes
            @attributes.slice(*permitted_file_set_attributes)
          else
            @attributes
          end
        end

        def permitted_file_set_attributes
          @file_set_klass.properties.keys.map(&:to_sym) + [:id, :edit_users, :edit_groups, :read_groups, :visibility]
        end

        def file_set_actor
          ::Hyrax::Actors::FileSetActor
        end

        def upload_file(file)
          u = ::Hyrax::UploadedFile.new
          @current_user = User.batch_user unless @current_user.present?
          u.user_id = @current_user.id unless @current_user.nil?
          u.file = ::CarrierWave::SanitizedFile.new(file)
          u.save
          u
        end
    end
  end
end
