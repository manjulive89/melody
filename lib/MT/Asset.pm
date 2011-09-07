# Movable Type (r) Open Source (C) 2001-2010 Six Apart, Ltd.
# This program is distributed under the terms of the
# GNU General Public License, version 2.
#
# $Id$

package MT::Asset;

use strict;
use MT::Tag;    # Holds MT::Taggable
use base qw( MT::Object MT::Taggable MT::Scorable );

__PACKAGE__->install_properties( {
                  column_defs => {
                                   'id' => 'integer not null auto_increment',
                                   'blog_id'     => 'integer not null',
                                   'label'       => 'string(255)',
                                   'url'         => 'string(255)',
                                   'description' => 'text',
                                   'file_path'   => 'string(255)',
                                   'file_name'   => 'string(255)',
                                   'file_ext'    => 'string(20)',
                                   'mime_type'   => 'string(255)',
                                   'parent'      => 'integer',
                  },
                  indexes => {
                       label      => 1,
                       file_ext   => 1,
                       parent     => 1,
                       created_by => 1,
                       created_on => 1,
                       blog_class_date =>
                         { columns => [ 'blog_id', 'class', 'created_on' ], },
                  },
                  class_type  => 'file',
                  audit       => 1,
                  meta        => 1,
                  datasource  => 'asset',
                  primary_key => 'id',
                }
);

sub list_default_terms {
    { class => '*', };
}

sub list_props {
    return {
        id =>
          { base => '__virtual.id', display => 'optional', order => 100, },
        label => {
            auto      => 1,
            label     => 'Label',
            order     => 200,
            display   => 'force',
            bulk_html => sub {
                my $prop = shift;
                my ( $objs, $app ) = @_;
                my @userpics = MT->model('objecttag')->load( {
                                      blog_id           => 0,
                                      object_datasource => 'asset',
                                      object_id => [ map { $_->id } @$objs ],
                                    },
                                    {
                                      fetchonly => { object_id => 1 },
                                      join => MT->model('tag')->join_on(
                                                undef,
                                                {
                                                  name => '@userpic',
                                                  id => \'= objecttag_tag_id'
                                                }
                                      ),
                                    }
                );
                my %is_userpic = map { $_->object_id => 1 } @userpics;
                my @rows;
                for my $obj (@$objs) {
                    my $id = $obj->id;
                    my $label
                      = MT::Util::remove_html(    $obj->label
                                               || $obj->file_name
                                               || 'Untitled' );
                    my $blog_id
                      = $obj->has_column('blog_id') ? $obj->blog_id
                      : $app->blog                  ? $app->blog->id
                      :                               0;
                    my $type = $prop->object_type;
                    my $edit_link =
                      $app->uri(
                        mode => 'view',
                        args =>
                          { _type => $type, id => $id, blog_id => $blog_id, },
                      );
                    my $class_type = $obj->class_type;

                    require MT::FileMgr;
                    my $fmgr      = MT::FileMgr->new('Local');
                    my $file_path = $obj->file_path;
                    ## FIXME: Hardcoded
                    my $thumb_size = 45;
                    my $userpic_sticker
                      = $is_userpic{ $obj->id }
                      ? q{<span class="inuse-userpic sticky-label">Userpic</span>}
                      : '';

                    if ( $file_path && $fmgr->exists($file_path) ) {
                        my $img
                          = MT->static_path
                          . 'images/asset/'
                          . $class_type
                          . '-45.png';
                        if ( $obj->has_thumbnail ) {
                            my ( $orig_width, $orig_height )
                              = ( $obj->image_width, $obj->image_height );
                            my ( $thumbnail_url, $thumbnail_width,
                                 $thumbnail_height );
                            if (    $orig_width > $thumb_size
                                 && $orig_height > $thumb_size )
                            {
                                (
                                   $thumbnail_url, $thumbnail_width,
                                   $thumbnail_height
                                  )
                                  = $obj->thumbnail_url(
                                                        Height => $thumb_size,
                                                        Width  => $thumb_size,
                                                        Square => 1
                                  );
                            }
                            elsif ( $orig_width > $thumb_size ) {
                                (
                                   $thumbnail_url, $thumbnail_width,
                                   $thumbnail_height
                                  )
                                  = $obj->thumbnail_url( Width => $thumb_size,
                                  );
                            }
                            elsif ( $orig_height > $thumb_size ) {
                                (
                                   $thumbnail_url, $thumbnail_width,
                                   $thumbnail_height
                                  )
                                  = $obj->thumbnail_url(
                                                     Height => $thumb_size, );
                            }
                            else {
                                (
                                   $thumbnail_url, $thumbnail_width,
                                   $thumbnail_height
                                  )
                                  = ( $obj->url, $orig_width, $orig_height );
                            }

                            my $thumbnail_width_offset
                              = int( ( $thumb_size - $thumbnail_width ) / 2 );
                            my $thumbnail_height_offset = int(
                                    ( $thumb_size - $thumbnail_height ) / 2 );

                            push @rows, qq{
                                <span class="title"><a href="$edit_link">$label</a></span>$userpic_sticker
                                <div class="thumbnail picture small">
                                  <img alt="" src="$thumbnail_url" style="padding: ${thumbnail_height_offset}px ${thumbnail_width_offset}px" />
                                </div>
                            };
                        } ## end if ( $obj->has_thumbnail)
                        else {
                            push @rows, qq{
                                <span class="title"><a href="$edit_link">$label</a></span>$userpic_sticker
                                <div class="file-type $class_type picture small">
                                  <img alt="$class_type" src="$img" class="asset-type-icon asset-type-$class_type" />
                                </div>
                            };
                        }
                    } ## end if ( $file_path && $fmgr...)
                    else {
                        my $img
                          = MT->static_path
                          . 'images/asset/'
                          . $class_type
                          . '-warning-45.png';
                        push @rows, qq{
                            <span class="title"><a href="$edit_link">$label</a></span>$userpic_sticker
                            <div class="file-type missing picture small">
                              <img alt="$class_type" src="$img" class="asset-type-icon asset-type-$class_type" />
                            </div>
                        };
                    }
                } ## end for my $obj (@$objs)
                @rows;
            },
        },
        author_name => { base => '__virtual.author_name', order => 300, },
        blog_name   => {
                       base    => '__virtual.blog_name',
                       order   => 400,
                       display => 'default',
        },
        created_on => {
                        base    => '__virtual.created_on',
                        order   => 500,
                        display => 'default',
        },

        modified_on =>
          { base => '__virtual.modified_on', display => 'none', },
        class => {
            label   => 'Type',
            col     => 'class',
            display => 'none',
            base    => '__virtual.single_select',
            terms   => sub {
                my $prop = shift;
                my ( $args, $db_terms, $db_args ) = @_;
                my $value = $args->{value};
                $db_args->{no_class} = 0;
                $db_terms->{class}   = $value;
                return;
            },
            ## FIXME: Get these values from registry or somewhere...
            single_select_options => [ {
                                          label => MT->translate('Image'),
                                          value => 'image',
                                       },
                                       {
                                          label => MT->translate('Audio'),
                                          value => 'audio',
                                       },
                                       {
                                          label => MT->translate('Video'),
                                          value => 'video',
                                       },
                                       {
                                          label => MT->translate('File'),
                                          value => 'file',
                                       },
            ],
        },
        description =>
          { auto => 1, display => 'none', label => 'Description', },
        file_name => { auto => 1, display => 'none', label => 'Filename', },
        file_ext =>
          { auto => 1, display => 'none', label => 'File Extension', },
        image_width => {
            label     => 'Pixel width',
            base      => '__virtual.integer',
            display   => 'none',
            meta_type => 'image_width',
            col       => 'vinteger',
            raw       => sub {
                my ( $prop, $asset ) = @_;
                my $meta = $prop->meta_type;
                $asset->has_meta( $prop->meta_type ) or return;
                return $asset->$meta;
            },
            terms => sub {
                my $prop = shift;
                my ( $args, $db_terms, $db_args ) = @_;
                my $super_terms = $prop->super(@_);
                $db_args->{joins} ||= [];
                push @{ $db_args->{joins} },
                  MT->model('asset')->meta_pkg->join_on(
                                                 undef,
                                                 {
                                                   type => $prop->meta_type,
                                                   asset_id => \"= asset_id",
                                                   %$super_terms,
                                                 },
                  );
            },
        },
        image_height => {
                          base      => 'asset.image_width',
                          label     => 'Pixel height',
                          meta_type => 'image_height',
        },
        tag            => { base => '__virtual.tag', tagged_class => '*', },
        except_userpic => {
            base      => '__virtual.hidden',
            label     => 'Except Userpic',
            display   => 'none',
            view      => 'system',
            singleton => 1,
            terms     => sub {
                my $prop = shift;
                my ( $args, $db_terms, $db_args ) = @_;

                my $tag = MT->model('tag')->load(
                                                 { name => '@userpic', },
                                                 {
                                                   fetchonly => { id => 1, },
                                                   binary => { name => 1 },
                                                 }
                );

                if ($tag) {
                    $db_args->{joins} ||= [];
                    push @{ $db_args->{joins} },
                      MT->model('objecttag')->join_on(
                         undef,
                         [ [
                              { tag_id => { not => $tag->id }, },
                              '-or',
                              { tag_id => \'IS NULL', },
                           ],
                           '-and',
                           [
                              { object_datasource => MT::Asset->datasource },
                              '-or',
                              { object_datasource => \'IS NULL' },
                           ],
                         ],
                         {
                           unique    => 1,
                           type      => 'left',
                           condition => 'object_id',
                         }
                      );
                } ## end if ($tag)
            },
        },
        author_status => {
            label   => 'Author Status',
            display => 'none',
            base    => '__virtual.single_select',
            terms   => sub {
                my $prop = shift;
                my ( $args, $base_terms, $base_args, $opts, ) = @_;
                my $val = $args->{value};
                if ( $val eq 'deleted' ) {
                    $base_args->{joins} ||= [];
                    push @{ $base_args->{joins} },
                      MT->model('author')->join_on(
                              undef,
                              { id => \'is null', },
                              {
                                type      => 'left',
                                condition => { id => \'= asset_created_by' },
                              },
                      );
                }
                else {
                    my %statuses = (
                                     active   => MT::Author::ACTIVE(),
                                     disabled => MT::Author::INACTIVE(),
                                     pending  => MT::Author::PENDING(),
                    );
                    my $status = $statuses{ $args->{value} };
                    $base_args->{joins} ||= [];
                    push @{ $base_args->{joins} },
                      MT->model('author')->join_on( undef,
                          { id => \'= asset_created_by', status => $status, },
                      );
                }
            },
            single_select_options => [ {
                                          label => MT->translate('Deleted'),
                                          value => 'deleted',
                                       },
                                       {
                                          label => MT->translate('Enabled'),
                                          value => 'active',
                                       },
                                       {
                                          label => MT->translate('Disabled'),
                                          value => 'disabled',
                                       },
            ],
        },
    };
} ## end sub list_props

require MT::Asset::Image;
require MT::Asset::Audio;
require MT::Asset::Video;

sub extensions {
    my $pkg = shift;
    return undef unless @_;

    my ($this_pkg) = caller;
    my ($ext)      = @_;
    return \@$ext unless MT->config('AssetFileTypes');

    my $file_types = MT->config('AssetFileTypes')->{$this_pkg} || '';
    my @custom_ext = map {qr/$_/i} split( /\s*,\s*/, $file_types );
    my %seen;
    my ($new_ext) = grep { ++$seen{$_} < 2 }[ @$ext, @custom_ext ];

    return \@$new_ext;
}

# This property is a meta-property.
sub file_path {
    my $asset = shift;
    my $path  = $asset->SUPER::file_path(@_);
    return $path if defined($path) && ( $path !~ m!^\$! ) && ( -f $path );

    $path = $asset->cache_property(
        sub {
            my $path = $asset->SUPER::file_path();
            if ( $path && ( $path =~ m!^\%([ras])! ) ) {
                my $blog = $asset->blog;
                my $root = !$blog
                  || $1 eq 's' ? MT->instance->static_file_path
                  : $1  eq 'r' ? $blog->site_path
                  :              $blog->archive_path;
                $root =~ s!(/|\\)$!!;
                $path =~ s!^\%[ras]!$root!;
            }
            $path;
        },
        @_
    );
    return $path;
} ## end sub file_path

sub url {
    my $asset = shift;
    my $url   = $asset->SUPER::url(@_);
    return $url
      if defined($url) && ( $url !~ m!^\%! ) && ( $url =~ m!^https://! );

    $url = $asset->cache_property(
        sub {
            my $url = $asset->SUPER::url();
            if ( $url =~ m!^\%([ras])! ) {
                my $blog = $asset->blog;
                my $root = !$blog || $1 eq 's' ? MT->instance->static_path
                  : $1 eq 'r' ? $blog->site_url
                  :             $blog->archive_url;
                $root =~ s!/$!!;
                $url  =~ s!^\%[ras]!$root!;
            }
            return $url;
        },
        @_
    );
    return $url;
} ## end sub url

# Returns a localized name for the asset type. For MT::Asset, this is simply
# 'File'.
sub class_label {
    MT->translate('Asset');
}

sub class_label_plural {
    MT->translate("Assets");
}

# Removes the asset, associated tags and related file.
# TBD: Should we track and remove any generated thumbnail files here too?
sub remove {
    my $asset = shift;
    if ( ref $asset ) {
        my $blog = MT::Blog->load( $asset->blog_id );
        require MT::FileMgr;
        my $fmgr = $blog ? $blog->file_mgr : MT::FileMgr->new('Local');
        my $file = $asset->file_path;
        unless ( $fmgr->delete($file) ) {
            my $app = MT->instance;
            $app->log( {
                   message =>
                     $app->translate(
                       "Could not remove asset file [_1] from filesystem: [_2]",
                       $file,
                       $fmgr->errstr
                     ),
                   level    => MT::Log::ERROR(),
                   class    => 'asset',
                   category => 'delete',
                }
            );
        }
        $asset->remove_cached_files;

        # remove children.
        my $class = ref $asset;
        my $iter
          = __PACKAGE__->load_iter( { parent => $asset->id, class => '*' } );
        while ( my $a = $iter->() ) {
            $a->remove;
        }

        # Remove MT::ObjectAsset records
        $class = MT->model('objectasset');
        $iter = $class->load_iter( { asset_id => $asset->id } );
        while ( my $o = $iter->() ) {
            $o->remove;
        }
    } ## end if ( ref $asset )

    $asset->SUPER::remove(@_);
} ## end sub remove

sub save {
    my $asset = shift;
    if ( defined $asset->file_ext ) {
        $asset->file_ext( lc( $asset->file_ext ) );
    }

    unless ( $asset->SUPER::save(@_) ) {

        # TODO - note to committers: should this be here? Seems odd.
        print STDERR "error during save: " . $asset->errstr . "\n";
        die $asset->errstr;
    }
}

sub is_associated {
    my $asset = shift;
    my ($obj) = @_;
    return MT->model('objectasset')->exist( {
                                              asset_id  => $asset->id,
                                              object_ds => $obj->class_type,
                                              object_id => $obj->id
                                            }
    );
}

sub associate {
    my $asset = shift;
    my ( $obj, $embedded ) = @_;
    my $object_asset = MT->model('objectasset')->new;
    $object_asset->object_ds( $obj->class_type );
    $object_asset->object_id( $obj->id );
    $object_asset->asset_id( $asset->id );
    $object_asset->embedded($embedded) if $embedded;
    $object_asset->blog_id( $obj->blog_id ) if $obj->has_column('blog_id');
    $object_asset->save
      or return $asset->error("Failed to associate object with asset");

}

sub clear_associations {
    my $asset = shift;
    my ($obj) = @_;
    MT->model('objectasset')
      ->remove( { object_id => $obj->id, object_ds => $obj->class_type } )
      or return $obj->error("Failed to clear associations with asset");

}

# This method is a static method. It does not require an instance for invokation.
# This method loads an array of assets associated with the object provided.
sub load_associations {
    my $class = shift;
    my ($obj) = @_;
    my $join_str = '= asset_id';
    require MT::ObjectAsset;
    my @assets =
        MT->model('asset')->load(
            { class => '*' },
            {
                join =>
                    MT::ObjectAsset->join_on(
                        undef,
                        {
                            asset_id  => \$join_str,
                            object_ds => $obj->class_type,
                            object_id => $obj->id
                        }
                    )
            }
        );
}

sub unassociate {
    my $asset = shift;
    my ($obj) = @_;
    return MT->model('objectasset')->remove( {
                                               object_id => $obj->id,
                                               object_ds => $obj->class_type,
                                               asset_id  => $asset->id
                                             }
    ) or return $asset->error("Failed to unassociate object with asset");
}

sub remove_cached_files {
    my $asset = shift;

    # remove any asset cache files that exist for this asset
    my $blog = $asset->blog;
    if ( $asset->id && $blog ) {
        my $cache_dir = $asset->_make_cache_path;
        if ($cache_dir) {
            require MT::FileMgr;
            my $fmgr = $blog->file_mgr || MT::FileMgr->new('Local');
            if ($fmgr) {
                my $basename = $asset->file_name;
                my $ext      = '.' . $asset->file_ext;
                $basename =~ s/$ext$//;
                my $cache_glob = File::Spec->catfile( $cache_dir,
                                              $basename . '-thumb-*' . $ext );
                my @files = glob($cache_glob);
                foreach my $file (@files) {
                    unless ( $fmgr->delete($file) ) {
                        my $app = MT->instance;
                        $app->log( {
                               message =>
                                 $app->translate(
                                   "Could not remove asset file [_1] from filesystem: [_2]",
                                   $file,
                                   $fmgr->errstr
                                 ),
                               level    => MT::Log::ERROR(),
                               class    => 'asset',
                               category => 'delete',
                            }
                        );
                    }
                }
            } ## end if ($fmgr)
        } ## end if ($cache_dir)
    } ## end if ( $asset->id && $blog)
    1;
} ## end sub remove_cached_files

# Returns a true/false response based on whether the active package
# has extensions registered that match the requested filename.
sub can_handle {
    my ( $pkg, $filename ) = @_;

    # undef is returned from fileparse if the extension is not known.
    require File::Basename;
    my $ext = $pkg->extensions || [];
    return ( File::Basename::fileparse( $filename, @$ext ) )[2] ? 1 : 0;
}

# Given a filename, returns an appropriate MT::Asset class to associate
# with it. This lookup is based purely on file extension! If none can
# be found, it returns MT::Asset.
sub handler_for_file {
    my $pkg = shift;
    my ($filename) = @_;
    my $types;

    # special case to check for all registered classes, not just
    # those that are subclasses of this package.
    if ( $pkg eq 'MT::Asset' ) {
        $types = [ keys %{ $pkg->properties->{__type_to_class} || {} } ];
    }
    $types ||= $pkg->type_list;
    if ($types) {
        foreach my $type (@$types) {
            my $this_pkg = $pkg->class_handler($type);
            if ( $this_pkg->can_handle($filename) ) {
                return $this_pkg;
            }
        }
    }
    __PACKAGE__;
} ## end sub handler_for_file

sub type_list {
    my $pkg       = shift;
    my $props     = $pkg->properties;
    my $col       = $props->{class_column};
    my $this_type = $props->{class_type};
    my @classes   = values %{ $props->{__class_to_type} };
    @classes = grep {m/^\Q$this_type\E:/} @classes;
    push @classes, $this_type;
    return \@classes;
}

sub metadata {
    my $asset = shift;
    return {
        MT->translate("Tags")        => MT::Tag->join( ',', $asset->tags ),
        MT->translate("Description") => $asset->description,
        MT->translate("Name")        => $asset->label,
        url                          => $asset->url,
        MT->translate("URL")         => $asset->url,
        MT->translate("Location")    => $asset->file_path,
        name                         => $asset->file_name,
        'class'                      => $asset->class,
        ext                          => $asset->file_ext,
        mime_type                    => $asset->mime_type,

        # duration => $asset->duration,
    };
}

sub has_thumbnail {
    0;
}

sub thumbnail_file {
    undef;
}

sub thumbnail_filename {
    undef;
}

sub stock_icon_url {
    undef;
}

sub thumbnail_url {
    my $asset = shift;
    my (%param) = @_;

    require File::Basename;
    if ( my ( $thumbnail_file, $w, $h ) = $asset->thumbnail_file(@_) ) {
        return $asset->stock_icon_url(@_) if !defined $thumbnail_file;
        my $file            = File::Basename::basename($thumbnail_file);
        my $asset_file_path = $asset->SUPER::file_path();
        my $site_url;
        my $blog = $asset->blog;
        if ( !$blog ) {
            $site_url = $param{Pseudo} ? '%s' : MT->instance->static_path;
            $site_url .= '/' unless $site_url =~ m!/$!;
            $site_url .= 'support/';
        }
        elsif ( $asset_file_path =~ m/^%a/ ) {
            $site_url = $param{Pseudo} ? '%a' : $blog->archive_url;
        }
        else {
            $site_url = $param{Pseudo} ? '%r' : $blog->site_url;
        }

        if ( $file && $site_url ) {
            require MT::Util;
            my $path = $param{Path};
            if ( !defined $path ) {
                $path = MT::Util::caturl( MT->config('AssetCacheDir'),
                                       unpack( 'A4A2', $asset->created_on ) );
            }
            else {
                require File::Spec;
                my @path = File::Spec->splitdir($path);
                $path = '';
                for my $p (@path) {
                    $path = MT::Util::caturl( $path, $p );
                }
            }
            $file =~ s/%([A-F0-9]{2})/chr(hex($1))/gei;
            $site_url = MT::Util::caturl( $site_url, $path, $file );
            return ( $site_url, $w, $h );
        }
    } ## end if ( my ( $thumbnail_file...))

    # Use a stock icon
    return $asset->stock_icon_url(@_);
} ## end sub thumbnail_url

sub as_html {
    my $asset      = shift;
    my ($param)    = @_;
    my $fname      = $asset->file_name;
    my $is_cf_edit = eval {

        # FIXME Wrapped in an eval because:
        #   1) It better highlights a call from the object layer
        #      to the application layer that should probably be
        #      reviewed for soundness.
        #
        #   2) The call below ends in a fatal error unless the
        #      current instances in a MT::App subclass
        MT->instance->query->param('edit_field') =~ m/^customfield/;
    };
    require MT::Util;
    my $text = sprintf '<a href="%s">%s</a>',
      MT::Util::encode_html( $asset->url ), MT::Util::encode_html($fname);
    return ( $param->{enclose} || $is_cf_edit )
      ? $asset->enclose($text)
      : $text;
} ## end sub as_html

sub enclose {
    my $asset  = shift;
    my ($html) = @_;
    my $id     = $asset->id;
    my $type   = $asset->class;
    return
      qq{<form mt:asset-id="$id" class="mt-enclosure mt-enclosure-$type" style="display: inline;">$html</form>};
}

# Return a HTML snippet of form options for inserting this asset
# into a web page. Default behavior is no options.
sub insert_options {
    my $asset = shift;
    my ($param) = @_;
    return undef;
}

sub on_upload {
    my $asset = shift;
    my ($param) = @_;
    1;
}

sub edit_template_param {
    my $asset = shift;
    my ( $cb, $app, $param, $tmpl ) = @_;
    return;
}

sub set_values_from_query {
    my $asset = shift;
    my ($q) = @_;

    # Set the known columns from the form, if they're set. Subclasses can
    # opt out or decorate this behavior by overriding the method.
    my $names = $asset->column_names;
    my %values;
    for my $field (@$names) {
        $values{$field} = $q->param($field) if defined $q->param($field);
    }
    $asset->set_values( \%values );

    1;
}

# $pseudo parameter causes function to return '%r' as
# root instead of blog site path
sub _make_cache_path {
    my $asset = shift;
    my ( $path, $pseudo ) = @_;
    my $blog = $asset->blog;

    require File::Spec;
    my $year_stamp  = '';
    my $month_stamp = '';
    if ( !defined $path ) {
        $year_stamp  = unpack 'A4',    $asset->created_on;
        $month_stamp = unpack 'x4 A2', $asset->created_on;
        $path        = MT->config('AssetCacheDir');
    }
    else {
        my $merge_path = '';
        my @split      = File::Spec->splitdir($path);
        for my $p (@split) {
            $merge_path = File::Spec->catfile( $merge_path, $p );
        }
        $path = $merge_path if $merge_path;
    }

    my $asset_file_path = $asset->SUPER::file_path();
    my $format;
    my $root_path;
    if ( !$blog ) {
        $format = '%s';
        $root_path
          = File::Spec->catdir( MT->instance->static_file_path, 'support' );
    }
    elsif ( $asset_file_path =~ m/^%a/ ) {
        $format    = '%a';
        $root_path = $blog->archive_path;
    }
    else {
        $format    = '%r';
        $root_path = $blog->site_path;
    }

    my $real_cache_path
      = File::Spec->catdir( $root_path, $path, $year_stamp, $month_stamp );
    if ( !-d $real_cache_path ) {
        require MT::FileMgr;
        my $fmgr = $blog ? $blog->file_mgr : MT::FileMgr->new('Local');

        # The change below is related to
        # http://bugs.movabletype.org/?82495
        unless ( $fmgr->mkpath($real_cache_path) ) {
            my $app = MT->instance;
            $app->log( {
                         message =>
                           $app->translate(
                                    "Could not create asset cache path: [_1]",
                                    $fmgr->errstr
                           ),
                         level    => MT::Log::ERROR(),
                         class    => 'asset',
                         category => 'cache',
                       }
            );
            return undef;
        }
    } ## end if ( !-d $real_cache_path)

    my $asset_cache_path =
      File::Spec->catdir( ( $pseudo ? $format : $root_path ),
                          $path, $year_stamp, $month_stamp );
    $asset_cache_path;
} ## end sub _make_cache_path

1;

__END__

=head1 NAME

MT::Asset

=head1 SYNOPSIS

    use MT::Asset;

    # Example

=head1 DESCRIPTION

This module provides an object definition for a file that is placed under
MT's control for publishing.

=head1 METHODS

=head2 MT::Asset->new

Constructs a new asset object. The base class is the generic asset object,
which represents a generic file.

=head2 MT::Asset->handler_for_file($filename)

Returns a I<MT::Asset> package suitable for the filename given. This
determination is typically made based on the file's extension.

=head2 is_associated( $obj )

Return true if the current asset is associated with the given object and
false otherwise.

=head2 associate( $obj, $embedded )

Associates an asset with an instance of an MT::Object subclass (e.g. an
MT::Entry instance). This association is what allows the CMS to track
and display a list of objects (usually entries) with which a given asset
is associated or inserted into.

The C<$embedded> parameter is a boolean flag indicating whether the asset
is embedded in the associate entry/object.

=head2 unassociate( $obj )

Removes an association between an instance of an MT::Object subclass (e.g. 
an MT::Entry instance) and an asset.

=head2 MT::Asset->clear_associations( $obj )

Clear all associations between all assets and the provided object.

=head1 AUTHORS & COPYRIGHT

Please see the I<MT> manpage for author, copyright, and license information.

=cut
