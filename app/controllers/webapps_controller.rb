class WebappsController < ApplicationController
  include SocialStream::Controllers::Objects

  def show
    respond_to do |format|
      format.zip {
        resource.increment_download_count
        return send_file resource.getZipPath(), :type=>"application/zip"
      }
      format.json {
        render :json => resource.as_json
      }
      format.full{
        @webapp = resource
      }
      format.all {
        super
      }
    end
  end

  def update
    super
  end

  def destroy
    destroy! do |format|
      format.html {
        redirect_to url_for(current_subject)
       }
    end
  end


  private

  def allowed_params
    [:lourl,  :lopath, :zipurl, :zippath, :width, :height, :language, :age_min, :age_max, :scope, :avatar, :tag_list=>[]]
  end
  
end

