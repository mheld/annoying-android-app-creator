#!/usr/bin/env ruby 

#   Copyright (c) 2011 Marc Held. Licensed under the MIT License:
#   http://www.opensource.org/licenses/mit-license.php

###############################################################################
#STATICS#######################################################################
###############################################################################

@@manifest = <<-MANIFEST
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
      package="<%= package %>"
      android:versionCode="2"
      android:versionName="1.1">
    <uses-sdk android:minSdkVersion="7" />

    <application android:icon="@drawable/icon" 
    	android:label="@string/app_name"
    	android:theme="@android:style/Theme.NoTitleBar">
        <activity android:name=".Viewer"
			android:label="@string/app_name"
			android:configChanges="keyboard|keyboardHidden|orientation"
			android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>
</manifest>
MANIFEST

@@properties = <<-PROP
key.store=keystore
key.alias=<%= title %>
PROP

@@layout = <<-MAIN
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
	android:layout_height="fill_parent"
	android:layout_width="fill_parent" 
	android:orientation="vertical">
	
	<VideoView android:id="@+id/video" 
		android:layout_height="fill_parent"
		android:layout_width="fill_parent" />

</LinearLayout>
MAIN

@@strings = <<-STRINGS
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<resources>
    <string name="app_name"><%= title %></string>
</resources>
STRINGS

@@java = <<-VIEWER
package <%= package %>;

import <%= package %>.R;

import android.app.Activity;
import android.net.Uri;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnTouchListener;
import android.widget.VideoView;

public class Viewer extends Activity {
	VideoView videoView;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.main);

		videoView = (VideoView)this.findViewById(R.id.video);
		Uri video = Uri.parse("android.resource://"+getPackageName() + "/"+R.raw.video);
		videoView.setVideoURI(video);
		videoView.start();

		videoView.setOnTouchListener(new OnTouchListener(){
			@Override
			public boolean onTouch(View v, MotionEvent event) {
				videoView.seekTo(0);
				if(videoView.isPlaying()){
					//don't need to start playing again
				}else{
					videoView.start();
				}
				return true;
			}
		});

	}
}
VIEWER

###############################################################################
#APP###########################################################################
###############################################################################

require 'rubygems'
require 'trollop' 
require 'ostruct'
require 'fileutils'
require 'erubis'

class App
  VERSION = '0.0.1'
  
  attr_reader :options

  def initialize(arguments)
    @arguments = arguments
    
    # Set defaults
    @options = OpenStruct.new
  end

  # Parse options, then process the command
  def run
    parse_options
    process_arguments
    do_stuff
  end
  
  protected
  
    def parse_options
      
      opts = Trollop::options do
        version "droid_does_loopz #{VERSION} (c) 2011 Marc Held"
        banner = <<-EOS 
This app takes in a bunch of stuff and spits out a android-market ready
annoying app that loops a video whenever you tap on the screen.

Example:
    droid_does_loopz -v whip_my_hair.mov -t Whip My Hair -p com.annoy.whipmyhair -i icon.png

Usage: 
    droid_does_loopz [options]
where [options] are:
EOS
      
        opt :video,   "The video to play in the app",   :type => String
        opt :title,   "The title of the application",   :type => String
        opt :package, "The package of the application", :type => String
        opt :icon,    "The app icon",                   :type => String
      end
      
      Trollop::die :video,   "must be a video"   unless File.exist?(opts[:video]) if opts[:video]
      Trollop::die :title,   "must be provided"   unless opts[:title]
      Trollop::die :package, "must be a package" unless opts[:package]
      Trollop::die :icon,    "must be a ican"    unless File.exist?(opts[:icon]) if opts[:icon]
      
      opts.each do |k, v|
        @options.send("#{k}=", v)
      end
    end
    
    # Setup the arguments
    def process_arguments
      @title = @options.title
      @package = @options.package
      @video = @options.video
      @icon = @options.icon
      @files = [{:value => @@manifest, :location => "AndroidManifest.xml"},
                {:value => @@properties, :location => "build.properties"},
                {:value => @@layout, :location => "res/layout/main.xml"},
                {:value => @@strings, :location => "res/values/strings.xml"},
                {:value => @@java, :location => "src/#{@package.gsub(".","/")}/Viewer.java"}]
    end
    
    def do_stuff
      render_files
    end
end

def render_files
  
  #read in the media
  @video = File.read(@video)
  @icon = File.read(@icon)
  
  #create a new skeleton
  foldername = @title.gsub(" ", "_").downcase
  FileUtils.mkdir_p(foldername)
  Dir.chdir(foldername)
  ["src/#{@package.gsub(".","/")}", "res/values", "res/raw", "res/layout"].each do |folder|
    FileUtils.mkdir_p(folder)
  end
  
  #pop out the media
  File.open("res/raw/video", 'w'){|io| io.write @video }
  ["/", "-hdpi/", "-ldpi/", "-mdpi/"].map{|s| "res/drawable"+s}.each do |i|
    FileUtils.mkdir_p(i)
    File.open(i+"icon.png", 'w+'){|f|
      f.write @icon
    }
  end
  
  #render the erb files to their new home
  @files.each do |p|
    template = Erubis::Eruby.new(p[:value])
    File.open(p[:location], 'w') do |io|
      io.write template.result(:title => @title, :package => @package)
    end
  end
  
  #generate a keystore
   %x[keytool -genkey -v -keystore keystore -alias #{@title} -keyalg RSA -validity 10000]
   
   #update all android generated stuff
   %x[android update project --target 7 --path ./]
  
  #generate an apk
   %x[ant release]
end

# Create and run the application
app = App.new(ARGV)
app.run