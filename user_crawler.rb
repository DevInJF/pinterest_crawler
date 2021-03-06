require_relative 'crawler'
require 'debugger'

class UserCrawler < PinterestCrawler

  def initialize(params = {seed: nil, append_to_file: true})
    #params[:append_to_file] = true if params[:append_to_file].nil?
    # always overwrite for now
    params[:append_to_file] = false

    super params
    @users       = []
    @users_slugs_q = params[:seed].nil? ? [] : [params[:seed]]
    @crawled_users_ids = {} 
    @users_file  = File.new("users.json", file_mode)
    @total_users_crawled = 0
    @crawling_limit = 50
  end

  # given slug of a user, get the users info + all her following and followers
  # also all of their following and followers (BFS) so we get the users info first
  def crawl_users_from_seed(seed = @current_user_slug)
    while @users_slugs_q.size > 0 && @total_users_crawled < @crawling_limit
      begin
        crawl_current_user(@users_slugs_q[0])
        @users_slugs_q.delete_at(0)
      rescue Exception => e
        puts e
        puts "There was a problem with the current user: #{@users_slugs_q[0]}".red
        @users_slugs_q.delete_at(0)
        next
      end
    end
    save_to_file
  end

  def crawl_current_user(seed = @current_user_slug)
    return if have_been_crawled?(seed) 
    puts "Crawling user #{seed} ..."

    seed_user = User.new(user_name: seed)
    @users << seed_user
    @total_users_crawled += 1
    
    following_html = users_following_page(seed)
    followers_html = users_followers_page(seed)
    
    seed_user.user_id = unique_id seed
    seed_user.about = followers_html.css(".content p").text 


    following_html.css(".person").each do |person_html|
      user_name = person_html.css(".PersonImage").attr("href").value.split("/")[1] 
      seed_user.following << unique_id(user_name)
      @users_slugs_q << user_name
    end

    followers_html.css(".person").each do |person_html|
      user_name = person_html.css(".PersonImage").attr("href").value.split("/")[1] 
      seed_user.followers << unique_id(user_name)
      @users_slugs_q << user_name
    end
    @crawled_users_ids[seed_user.user_id] = true
  end

  protected
  
  def have_been_crawled?(user_slug)
    id = unique_id user_slug
    !@crawled_users_ids[id].nil?
  end

  def save_to_file
    users = @users.collect {|user| user.to_json}
    users_json = JSON.generate(users)
    @users_file.puts users_json 
  end

  def users_following_page(slug)
    get_page_html("#{url(slug)}following")
  end

  def users_followers_page(slug)
    get_page_html("#{url(slug)}followers")
  end
end
