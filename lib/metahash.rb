require "metahash/metadata"
require "metahash/version"

module MetaHash

	# When an active record object is loaded, convert to Metadata.
	# If for whatever reason we lose this Metadata class, we can read
	# the hash by creating class Metadata < Hash; end
	#
	# @param [Symbol] serialized_field name of the field to convert to Metadata
	def metadata_field_for(serialized_field)
		after_initialize do |record|
			# first check the type of the field
			# proceed if hash, abort if Metadata
			if record.has_attribute?(serialized_field)
				if [Hash, NilClass].include?(record.send(serialized_field).class)
					# alias the old method / field
					backup_name = "#{serialized_field}_original".to_sym
					# alias_method backup_name, serialized_field
					record.define_singleton_method backup_name, record.method(serialized_field)
					# name the metadata accessor the same as the original field
					# rails should automatically serialize this on save
					initial_value = record.send(backup_name) || {}
					record.send("#{serialized_field}=", Metadata.new(initial_value))
				end
			end
		end


		# create a before_save hook to store a pure Hash in the DB
		before_save do |record|
			@temp_metadata = record.send(serialized_field)
			record.send("#{serialized_field}=", @temp_metadata.to_hash) if @temp_metadata
		end

		# restore the metadata to the field
		after_save do |record|
			record.send("#{serialized_field}=", @temp_metadata) if @temp_metadata
		end

	end

end

if defined?(ActiveRecord::Base)
	ActiveRecord::Base.send :extend, MetaHash
end
