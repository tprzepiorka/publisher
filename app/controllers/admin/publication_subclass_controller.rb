class Admin::PublicationSubclassController < Admin::BaseController

  def show
    @resource = resource
    @latest_edition = resource.latest_edition
  end

  def create
    @resource = create_new
    if @resource.save
      redirect_to resource_path(@resource),
        :notice => "#{description(@resource)} successfully created"
      return
    else
      render :action => 'new'
    end
  end

  def destroy
    if resource.can_destroy?
      destroy! do
        redirect_to admin_root_url, :notice => "#{description(resource)} destroyed"
        return
      end
    else
      redirect_to resource_path(resource),
        :notice => "Cannot delete a #{description(resource).downcase} that has ever been published."
      return
    end
  end

  def update
    update! do |s,f|
      s.json { render :json => @resource }
      f.json { render :json => @resource.errors, :status => 406 }
    end
  end

private
  def description(r)
    r.class.to_s.underscore.humanize
  end
end